from sqlalchemy.orm import Session
from database import engine, Base, SessionLocal
import models
from models.user import User
from models.category import Category
from models.listing import Listing
from models.conversation import Conversation
from models.message import Message
from models.promotion_package import PromotionPackage
from models.promotion import Promotion
from models.payment import Payment
from services.auth_service import hash_password
from datetime import datetime, timedelta
import uuid

def seed():
    print("Initializing database schema...")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        print("Creating categories...")
        cat_names = ["Electronics", "Vehicles", "Real Estate", "Clothing", "Services", "Furniture"]
        cats = []
        for name in cat_names:
            cat = db.query(Category).filter(Category.name == name).first()
            if not cat:
                cat = Category(name=name, slug=name.lower().replace(" ", "-"))
                db.add(cat)
            cats.append(cat)
        db.commit()
        for cat in cats:
            db.refresh(cat)

        print("Creating users...")
        u_admin = db.query(User).filter(User.email == "admin@example.com").first()
        if not u_admin:
            u_admin = User(
                email="admin@example.com",
                password_hash=hash_password("Password123!"),
                full_name="Admin User",
                role="admin",
                account_status="active"
            )
            db.add(u_admin)
            
        u1 = db.query(User).filter(User.email == "user1@example.com").first()
        if not u1:
            u1 = User(
                email="user1@example.com",
                password_hash=hash_password("Password123!"),
                full_name="Emil Test",
                role="user",
                account_status="active"
            )
            db.add(u1)
            
        u2 = db.query(User).filter(User.email == "user2@example.com").first()
        if not u2:
            u2 = User(
                email="user2@example.com",
                password_hash=hash_password("Password123!"),
                full_name="Jane Doe",
                role="user",
                account_status="active"
            )
            db.add(u2)
            
        db.commit()
        if u_admin: db.refresh(u_admin)
        if u1: db.refresh(u1)
        if u2: db.refresh(u2)

        print("Creating listings...")
        listings = db.query(Listing).all()
        if len(listings) < 10:
            for i in range(10):
                l = Listing(
                    title=f"Sample Listing {i}",
                    description="iPhone 14 Pro 256GB Space Black, excellent condition, includes original box and charger",
                    price=10.0 * (i + 1),
                    currency="USD",
                    category_id=cats[i % len(cats)].id,
                    owner_id=u1.id if i % 2 == 0 else u2.id,
                    city="Bishkek",
                    status="approved",
                    published_at=datetime.utcnow()
                )
                db.add(l)
                listings.append(l)
            db.commit()
            for l in listings:
                db.refresh(l)

        print("Creating conversations...")
        convs = db.query(Conversation).all()
        if len(convs) < 3 and len(listings) >= 3:
            for i in range(3):
                p_a = min(u1.id, u_admin.id)
                p_b = max(u1.id, u_admin.id)
                existing_conv = db.query(Conversation).filter(
                    Conversation.listing_id == listings[i].id,
                    Conversation.participant_a_id == p_a,
                    Conversation.participant_b_id == p_b
                ).first()
                
                if not existing_conv:
                    conv = Conversation(
                        listing_id=listings[i].id,
                        participant_a_id=p_a,
                        participant_b_id=p_b,
                        created_by_user_id=u_admin.id
                    )
                    db.add(conv)
                    db.commit()
                    db.refresh(conv)
                    
                    msg = Message(
                        conversation_id=conv.id,
                        sender_id=u_admin.id,
                        text_body=f"Hello message {i}",
                        message_type="text",
                        is_read=False
                    )
                    db.add(msg)
                    db.commit()

        print("Creating promotion packages...")
        pkg1 = db.query(PromotionPackage).filter(PromotionPackage.name == "Basic Promo").first()
        if not pkg1:
            pkg1 = PromotionPackage(
                name="Basic Promo",
                name_ru="Базовое промо",
                description="3 days of promotion",
                promotion_type="featured",
                duration_days=3,
                price=5.00,
                currency="USD",
                is_active=True
            )
            db.add(pkg1)
            
        pkg2 = db.query(PromotionPackage).filter(PromotionPackage.name == "Premium Promo").first()
        if not pkg2:
            pkg2 = PromotionPackage(
                name="Premium Promo",
                name_ru="Премиум промо",
                description="7 days of promotion",
                promotion_type="featured",
                duration_days=7,
                price=10.00,
                currency="USD",
                is_active=True
            )
            db.add(pkg2)
        db.commit()
        if pkg1: db.refresh(pkg1)
            
        print("Creating payment and promotion records...")
        if len(listings) > 0 and pkg1:
            promo = db.query(Promotion).filter(Promotion.status == "active").first()
            if not promo:
                promo = Promotion(
                    listing_id=listings[0].id,
                    user_id=listings[0].owner_id,
                    package_id=pkg1.id,
                    promotion_type="featured",
                    status="active",
                    purchased_price=pkg1.price,
                    starts_at=datetime.utcnow(),
                    ends_at=datetime.utcnow() + timedelta(days=3)
                )
                db.add(promo)
                db.commit()
                db.refresh(promo)
                
                pay = Payment(
                    user_id=listings[0].owner_id,
                    promotion_id=promo.id,
                    amount=pkg1.price,
                    currency=pkg1.currency,
                    status="successful",
                    payment_provider="card",
                    provider_reference=str(uuid.uuid4()),
                    paid_at=datetime.utcnow(),
                    listing_id=listings[0].id
                )
                db.add(pay)
                db.commit()

        print("Database seeded successfully.")

    except Exception as e:
        db.rollback()
        with open("error.txt", "w", encoding="utf-8") as f:
            f.write(str(e))
        print(f"Error seeding database. Check error.txt.")
    finally:
        db.close()

if __name__ == "__main__":
    seed()
