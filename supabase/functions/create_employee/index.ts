// Supabase Edge Function: create an employee auth user and matching profile.
declare const Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

type EmployeePayload = {
  full_name?: string;
  email?: string;
  password?: string;
  phone?: string;
  role?: string;
  branch_id?: string;
  department_id?: string;
  team_id?: string;
  department?: string;
  team?: string;
  branch?: string;
  shift?: string;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

async function readText(response: Response) {
  const text = await response.text();
  try {
    return JSON.stringify(JSON.parse(text));
  } catch (_) {
    return text;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno?.env?.get?.('SUPABASE_URL') || '';
  const serviceRoleKey =
    Deno?.env?.get?.('SUPABASE_SERVICE_ROLE_KEY') ||
    Deno?.env?.get?.('SERVICE_ROLE_KEY') ||
    '';

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server misconfigured' }, 500);
  }

  const authHeader = req.headers.get('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const callerToken = authHeader.slice('Bearer '.length);
  const userRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${callerToken}`,
    },
  });

  if (!userRes.ok) {
    return jsonResponse({ error: 'Unauthorized user' }, 401);
  }

  const caller = await userRes.json();
  const callerId = caller.id;
  const profilesRes = await fetch(
    `${supabaseUrl}/rest/v1/profiles?auth_user_id=eq.${callerId}&select=role,organization_id`,
    {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!profilesRes.ok) {
    return jsonResponse(
      {
        error: 'Unable to verify admin profile',
        detail: await readText(profilesRes),
      },
      500,
    );
  }

  const profiles = await profilesRes.json();
  const callerProfile =
    Array.isArray(profiles) && profiles.length ? profiles[0] : null;
  const callerRole = callerProfile?.role?.toString().trim().toUpperCase();
  if (!callerProfile || !['ADMIN', 'SUPER_ADMIN'].includes(callerRole)) {
    return jsonResponse({ error: 'Forbidden' }, 403);
  }

  let body: EmployeePayload;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const fullName = body.full_name?.trim();
  const email = body.email?.trim().toLowerCase();
  const password = body.password || '';
  const role = (body.role || 'EMPLOYEE').trim().toUpperCase();

  if (!fullName || !email || !password) {
    return jsonResponse(
      { error: 'Name, email and password are required' },
      400,
    );
  }

  if (password.length < 6) {
    return jsonResponse(
      { error: 'Password must be at least 6 characters' },
      400,
    );
  }

  const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        phone: body.phone || null,
        requested_app: 'admin_created',
      },
    }),
  });

  if (!createRes.ok) {
    return jsonResponse(
      {
        error: 'Failed to create auth user',
        detail: await readText(createRes),
      },
      createRes.status === 422 ? 409 : 500,
    );
  }

  const newUser = await createRes.json();
  const newUserId = newUser.id;

  const rpcRes = await fetch(`${supabaseUrl}/rest/v1/rpc/generate_employee_id`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
  });

  let employeeId = '';
  if (rpcRes.ok) {
    employeeId = (await rpcRes.text()).replace(/"/g, '').trim();
  }
  if (!employeeId) {
    employeeId = `EMP-${Math.floor(Math.random() * 900000 + 100000)}`;
  }

  const profileInsert = await fetch(
    `${supabaseUrl}/rest/v1/profiles?on_conflict=auth_user_id`,
    {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates,return=representation',
      },
      body: JSON.stringify({
        auth_user_id: newUserId,
        role,
        full_name: fullName,
        email,
        employee_id: employeeId,
        status: 'ACTIVE',
        organization_id: callerProfile.organization_id,
        branch_id: body.branch_id || null,
        department_id: body.department_id || null,
        team_id: body.team_id || null,
        phone: body.phone || null,
        meta: {
          department: body.department || null,
          team: body.team || null,
          branch: body.branch || null,
          shift: body.shift || null,
        },
      }),
    },
  );

  if (!profileInsert.ok) {
    await fetch(`${supabaseUrl}/auth/v1/admin/users/${newUserId}`, {
      method: 'DELETE',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    return jsonResponse(
      {
        error: 'Failed to create employee profile',
        detail: await readText(profileInsert),
      },
      500,
    );
  }

  const createdProfile = await profileInsert.json();
  return jsonResponse({
    success: true,
    user: newUser,
    profile: createdProfile[0],
    password,
  });
});
