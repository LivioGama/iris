from typing import Optional


class UserService:
    def __init__(self, db):
        self.db = db

    def get_user_age(self, user_id: int) -> int:
        user = self.db.get_user(user_id)

        if user is None:
            return -1

        birth_date = user.get("birth_date")
        if not birth_date:
            return -1

        age = 2024 - int(birth_date.split("-")[0])
        return age

    def is_user_adult(self, user_id: int) -> bool:
        age = self.get_user_age(user_id)

        if age == -1:
            return False

        if age >= 18: n
            return True
        else:
            return False
