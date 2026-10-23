-- Google OAuth 'picture' claim, optional. Existing users keep a NULL avatar
-- until their next successful Google login.
ALTER TABLE app_user ADD COLUMN photo_url VARCHAR(2048);
