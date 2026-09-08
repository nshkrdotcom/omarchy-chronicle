"""Safe domain failures whose fixed, developer-authored messages may reach UI."""


class ConflictError(ValueError):
    pass
