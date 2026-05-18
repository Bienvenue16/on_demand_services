import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings


async def send_email(to: str, subject: str, html_body: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.EMAIL_FROM
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))
    await aiosmtplib.send(
        msg,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USER,
        password=settings.SMTP_PASSWORD,
        start_tls=True,
    )


async def send_verification_email(to: str, token: str) -> None:
    base_url = settings.STATIC_URL.split("/static")[0]
    url = f"{base_url}/auth/verify-email?token={token}"
    html = f"""
    <h2>Vérifiez votre adresse email</h2>
    <p>Cliquez sur le lien ci-dessous pour activer votre compte :</p>
    <p><a href="{url}">{url}</a></p>
    <p>Ce lien expire dans 24 heures.</p>
    """
    await send_email(to, "Vérification de votre email — Services App", html)


async def send_reset_password_email(to: str, token: str) -> None:
    base_url = settings.STATIC_URL.split("/static")[0]
    url = f"{base_url}/auth/reset-password?token={token}"
    html = f"""
    <h2>Réinitialisation de mot de passe</h2>
    <p>Cliquez sur le lien ci-dessous pour réinitialiser votre mot de passe :</p>
    <p><a href="{url}">{url}</a></p>
    <p>Ce lien expire dans 1 heure.</p>
    <p>Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>
    """
    await send_email(to, "Réinitialisation de mot de passe — Services App", html)
