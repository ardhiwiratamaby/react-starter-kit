-- Insert development user with password 'asdf'
-- This creates a test user for development purposes

-- First, let's check the current schema
\dt user*

-- Insert the user with email and password
INSERT INTO "user" (
    id,
    email,
    name,
    emailVerified,
    image,
    createdAt,
    updatedAt,
    isAnonymous
) VALUES (
    gen_random_uuid(),
    'dev@pronounce.app',
    'Development User',
    TRUE,
    NULL,
    NOW(),
    NOW(),
    FALSE
) ON CONFLICT (email) DO NOTHING;

-- Get the user ID to create the account record
DO $$
DECLARE
    user_id UUID;
BEGIN
    SELECT id INTO user_id FROM "user" WHERE email = 'dev@pronounce.app';

    -- Insert the account record with the hashed password
    INSERT INTO "account" (
        id,
        userId,
        type,
        provider,
        providerAccountId,
        refresh_token,
        access_token,
        expires_at,
        token_type,
        scope,
        id_token,
        session_state,
        password,
        createdAt,
        updatedAt
    ) VALUES (
        gen_random_uuid(),
        user_id,
        'credentials',
        'credentials',
        user_id::text,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        '$2b$10$jAWWwRuVgQu4Vr.L6BuD6egPkifLXf9F6ck4eXVm1VQljRusVWn82', -- bcrypt hash for 'asdf'
        NOW(),
        NOW()
    ) ON CONFLICT (userId, provider) DO NOTHING;

    RAISE NOTICE 'Development user created: dev@pronounce.app / password: asdf';
END $$;

-- Verify the user was created
SELECT u.email, u.name, u.emailVerified, u.isAnonymous, a.provider
FROM "user" u
LEFT JOIN "account" a ON u.id = a.userId
WHERE u.email = 'dev@pronounce.app';