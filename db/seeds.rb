# Role systemowe (jak w poprzedniej wersji, CreateRoleService). Bezpieczne do wielokrotnego uruchomienia.
Role::DEFAULTS.each_key { Role.find_or_create_default(it) }
