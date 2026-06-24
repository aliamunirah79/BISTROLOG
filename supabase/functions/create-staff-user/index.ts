import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", {
            headers: corsHeaders,
        });
    }

    try {
        if (req.method !== "POST") {
            return jsonResponse({ error: "Method not allowed" }, 405);
        }

        const authHeader = req.headers.get("Authorization");

        if (!authHeader) {
            return jsonResponse({ error: "Missing authorization header" }, 401);
        }

        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        if (!supabaseUrl || !anonKey || !serviceRoleKey) {
            return jsonResponse(
                { error: "Missing Supabase environment variables" },
                500,
            );
        }

        const userClient = createClient(supabaseUrl, anonKey, {
            global: {
                headers: {
                    Authorization: authHeader,
                },
            },
        });

        const adminClient = createClient(supabaseUrl, serviceRoleKey);

        const body = await req.json();

        const email = cleanString(body.email).toLowerCase();
        const password = cleanString(body.password);
        const username = cleanString(body.username);
        const fullName = cleanString(body.full_name);
        const role = cleanString(body.role).toLowerCase();
        const phone = cleanNullableString(body.phone);
        const branch = cleanNullableString(body.branch);
        const department = cleanNullableString(body.department);

        if (!email || !password || !username || !fullName || !role) {
            return jsonResponse(
                {
                    error:
                        "Full name, username, email, password and role are required.",
                },
                400,
            );
        }

        if (!email.includes("@")) {
            return jsonResponse({ error: "Invalid email address." }, 400);
        }

        if (!["staff", "supervisor", "manager"].includes(role)) {
            return jsonResponse({ error: "Invalid role." }, 400);
        }

        if (password.length < 8) {
            return jsonResponse(
                { error: "Temporary password must be at least 8 characters." },
                400,
            );
        }

        const {
            data: { user: currentUser },
            error: currentUserError,
        } = await userClient.auth.getUser();

        if (currentUserError || !currentUser) {
            return jsonResponse({ error: "Unauthorized." }, 401);
        }

        const { data: managerProfile, error: managerError } = await adminClient
            .from("profiles")
            .select("role, is_active, staff_status")
            .eq("id", currentUser.id)
            .maybeSingle();

        if (managerError || !managerProfile) {
            return jsonResponse(
                { error: "Manager profile not found." },
                403,
            );
        }

        if (
            managerProfile.role !== "manager" ||
            managerProfile.is_active !== true ||
            managerProfile.staff_status !== "active"
        ) {
            return jsonResponse(
                { error: "Only an active manager can create staff accounts." },
                403,
            );
        }

        const { data: existingUsername, error: usernameCheckError } =
            await adminClient
                .from("profiles")
                .select("id")
                .eq("username", username)
                .maybeSingle();

        if (usernameCheckError) {
            return jsonResponse({ error: usernameCheckError.message }, 400);
        }

        if (existingUsername) {
            return jsonResponse({ error: "Username already exists." }, 409);
        }

        const { data: existingEmail, error: emailCheckError } = await adminClient
            .from("profiles")
            .select("id")
            .eq("email", email)
            .maybeSingle();

        if (emailCheckError) {
            return jsonResponse({ error: emailCheckError.message }, 400);
        }

        if (existingEmail) {
            return jsonResponse({ error: "Email already exists." }, 409);
        }

        const { data: createdUser, error: createUserError } =
            await adminClient.auth.admin.createUser({
                email,
                password,
                email_confirm: true,
            });

        if (createUserError || !createdUser.user) {
            return jsonResponse(
                { error: createUserError?.message ?? "Failed to create auth user." },
                400,
            );
        }

        const newUserId = createdUser.user.id;
        const now = new Date().toISOString();

        const { error: profileInsertError } = await adminClient
            .from("profiles")
            .insert({
                id: newUserId,
                username,
                full_name: fullName,
                role,
                email,
                phone,
                branch,
                department,
                joined_at: now.substring(0, 10),
                is_active: true,
                staff_status: "active",
                must_change_password: true,
                created_at: now,
                updated_at: now,
            });

        if (profileInsertError) {
            await adminClient.auth.admin.deleteUser(newUserId);

            return jsonResponse(
                { error: profileInsertError.message },
                400,
            );
        }

        return jsonResponse(
            {
                message: "Staff account created successfully.",
                user_id: newUserId,
            },
            200,
        );
    } catch (error) {
        return jsonResponse(
            { error: error instanceof Error ? error.message : String(error) },
            500,
        );
    }
});

function cleanString(value: unknown): string {
    if (value === null || value === undefined) return "";
    return String(value).trim();
}

function cleanNullableString(value: unknown): string | null {
    const cleaned = cleanString(value);
    return cleaned.length ? null : cleaned;
}

function jsonResponse(body: Record<string, unknown>, status: number) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
        },
    });
}