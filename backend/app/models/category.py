from beanie import Document


class Category(Document):
    name: str
    slug: str
    icon: str = ""
    is_active: bool = True

    class Settings:
        name = "categories"
        indexes = ["slug"]
