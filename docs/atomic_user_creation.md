# VedaSentio — atomic user creation

Previously user creation and `user_homes` assignment were two independent
database operations. If the second operation failed, a user row could
remain without the intended home relation.

`UserRepository::create_user_with_home_access()` now performs the complete
registration flow in one PostgreSQL transaction (`pqxx::work`):

1. validate role,
2. verify that the target home exists,
3. check e-mail uniqueness,
4. insert the encrypted user,
5. insert `user_homes`,
6. commit.

If any step fails, no commit occurs and PostgreSQL rolls the whole operation
back. This demonstrates transaction atomicity: either both records are
persisted or neither is persisted.

`vedasentio_atomic_user_test.exe` intentionally uses a non-existent home and
verifies that no partial user remains in `users`.
