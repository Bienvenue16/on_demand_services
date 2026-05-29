"""
Script one-shot : crée un utilisateur admin en base.
Usage : python create_admin.py
"""
import asyncio
import bcrypt
from app.core.database import init_db
from app.models.user import User, UserRole


async def main():
    await init_db()

    email = input("Email admin : ").strip()
    password = input("Mot de passe : ").strip()
    full_name = input("Nom complet : ").strip()

    existing = await User.find_one(User.email == email)
    if existing:
        print(f"⚠  Un utilisateur avec cet email existe déjà (role: {existing.role}).")
        if existing.role != UserRole.admin:
            existing.role = UserRole.admin
            existing.is_verified = True
            existing.is_active = True
            await existing.save()
            print("✅ Rôle mis à jour → admin")
        else:
            print("✅ Déjà admin, rien à faire.")
        return

    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    user = User(
        email=email,
        hashed_password=hashed,
        full_name=full_name,
        role=UserRole.admin,
        is_verified=True,
        is_active=True,
    )
    await user.insert()
    print(f"✅ Admin créé : {email}")


if __name__ == "__main__":
    asyncio.run(main())
