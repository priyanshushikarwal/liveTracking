// Declare Deno for TypeScript compilation in the Edge Functions build
declare const Deno: any;

export default async function (req: Request) {
  const SUPABASE_URL = Deno?.env?.get?.('SUPABASE_URL') || '';
  const SERVICE_ROLE_KEY = Deno?.env?.get?.('SUPABASE_SERVICE_ROLE_KEY') || '';

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return new Response(JSON.stringify({ error: 'Server misconfigured' }), { status: 500 });
  }

  // Verify caller token is present
  const authHeader = req.headers.get('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
  }
  const callerToken = authHeader.slice('Bearer '.length);

  // Validate caller and check role by requesting /auth/v1/user with caller token
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${callerToken}` }
  });
  if (!userRes.ok) return new Response(JSON.stringify({ error: 'Unauthorized user' }), { status: 401 });
  const caller = await userRes.json();
  const callerId = caller.id;

  // Use service role to fetch caller profile and verify admin role
  const profilesRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?auth_user_id=eq.${callerId}&select=role,organization_id`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    }
  });
  const profiles = await profilesRes.json();
  const callerProfile = Array.isArray(profiles) && profiles.length ? profiles[0] : null;
  if (!callerProfile || !['ADMIN', 'SUPER_ADMIN'].includes(callerProfile.role)) {
    return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 });
  }

  const body = await req.json();
  const {
    full_name,
    email,
    phone,
    role = 'EMPLOYEE',
    branch_id,
    department_id,
    team_id,
    department,
    team,
    branch,
    shift,
  } = body;
  if (!email || !full_name) {
    return new Response(JSON.stringify({ error: 'missing fields' }), { status: 400 });
  }

  // Generate temporary password
  const tempPassword = 'TempPass@' + Math.floor(Math.random() * 9000 + 1000).toString();

  // Create auth user via admin endpoint
  const createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        full_name,
        phone,
        requested_app: 'admin_created'
      }
    })
  });

  if (!createRes.ok) {
    const errText = await createRes.text();
    return new Response(JSON.stringify({ error: 'failed to create user', detail: errText }), { status: 500 });
  }

  const newUser = await createRes.json();
  const newUserId = newUser.id;

  // Generate employee id via RPC
  const rpcRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/generate_employee_id`, {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    }
  });
  const empIdText = await rpcRes.text();
  let employee_id = '';
  try {
    // rpc returns plain text
    employee_id = empIdText.replace(/"/g, '').trim();
  } catch (_) {
    employee_id = 'EMP-' + Math.floor(Math.random() * 9000 + 1000).toString();
  }

  // Insert profile using service role
  const profileInsert = await fetch(`${SUPABASE_URL}/rest/v1/profiles?on_conflict=auth_user_id`, {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify({
      auth_user_id: newUserId,
      role: role,
      full_name,
      email,
      employee_id,
      status: 'ACTIVE',
      organization_id: callerProfile.organization_id,
      branch_id: branch_id || null,
      department_id: department_id || null,
      team_id: team_id || null,
      phone,
      meta: {
        department: department || null,
        team: team || null,
        branch: branch || null,
        shift: shift || null,
      }
    })
  });

  if (!profileInsert.ok) {
    const err = await profileInsert.text();
    return new Response(JSON.stringify({ error: 'failed to insert profile', detail: err }), { status: 500 });
  }

  const createdProfile = await profileInsert.json();

  return new Response(JSON.stringify({ success: true, user: newUser, profile: createdProfile[0], tempPassword }), { status: 200 });
}
