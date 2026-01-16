from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db.models import Avg
import uuid


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    bio = models.TextField(blank=True)
    
    def __str__(self):
        return self.user.username


class Category(models.Model):
    """Catégories d'applications similaires à l'App Store"""
    
    CATEGORY_CHOICES = [
        ('games', 'Jeux'),
        ('entertainment', 'Divertissement'),
        ('social', 'Réseaux sociaux'),
        ('productivity', 'Productivité'),
        ('utilities', 'Utilitaires'),
        ('education', 'Éducation'),
        ('lifestyle', 'Style de vie'),
        ('finance', 'Finance'),
        ('health', 'Santé & Forme'),
        ('news', 'Actualités'),
        ('music', 'Musique'),
        ('photo_video', 'Photo & Vidéo'),
        ('shopping', 'Shopping'),
        ('travel', 'Voyages'),
        ('food', 'Nourriture & Boissons'),
        ('sports', 'Sports'),
        ('weather', 'Météo'),
        ('books', 'Livres'),
        ('business', 'Business'),
        ('developer', 'Développement'),
        ('graphics', 'Graphisme & Design'),
        ('kids', 'Enfants'),
        ('medical', 'Médical'),
        ('navigation', 'Navigation'),
        ('reference', 'Référence'),
    ]
    
    slug = models.CharField(max_length=50, unique=True, choices=CATEGORY_CHOICES)
    name = models.CharField(max_length=100)
    icon = models.CharField(max_length=50, blank=True, help_text="Nom de l'icône Material/SF Symbol")
    color = models.CharField(max_length=7, default='#007AFF', help_text="Couleur hex de la catégorie")
    order = models.IntegerField(default=0, help_text="Ordre d'affichage")
    
    class Meta:
        verbose_name_plural = "Categories"
        ordering = ['order', 'name']
    
    def __str__(self):
        return self.name


class MiniApp(models.Model):
    """Application enrichie avec métadonnées complètes style App Store"""
    
    AGE_RATINGS = [
        ('4+', '4+'),
        ('9+', '9+'),
        ('12+', '12+'),
        ('17+', '17+'),
    ]
    
    # Identité
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='apps', null=True, blank=True)
    bundle_id = models.CharField(max_length=100, unique=True, help_text="ex: com.ondes.calculator")
    name = models.CharField(max_length=100)
    
    # Catégorisation
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='apps')
    tags = models.CharField(max_length=200, blank=True, help_text="Tags séparés par des virgules")
    
    # Description & Contenu
    description = models.TextField(help_text="Description courte")
    full_description = models.TextField(blank=True, help_text="Description complète avec changelog, fonctionnalités...")
    whats_new = models.TextField(blank=True, help_text="Nouveautés de la dernière version")
    
    # Médias
    icon = models.ImageField(upload_to='icons/', blank=True, null=True)
    banner = models.ImageField(upload_to='banners/', blank=True, null=True, help_text="Bannière 1200x630px")
    
    # Classification
    age_rating = models.CharField(max_length=5, choices=AGE_RATINGS, default='4+')
    
    # Métadonnées techniques
    size_bytes = models.BigIntegerField(default=0, help_text="Taille en octets")
    languages = models.CharField(max_length=200, default='fr', help_text="Codes langue séparés par virgules")
    privacy_url = models.URLField(blank=True, help_text="Lien politique de confidentialité")
    support_url = models.URLField(blank=True, help_text="Lien support")
    website_url = models.URLField(blank=True, help_text="Site web de l'app")
    
    # Statistiques
    downloads_count = models.PositiveIntegerField(default=0)
    featured = models.BooleanField(default=False, help_text="Mise en avant dans le store")
    featured_order = models.IntegerField(default=0, help_text="Ordre d'affichage si featured")
    
    # Dates
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-featured', '-downloads_count', '-created_at']
    
    def __str__(self):
        return self.name
    
    @property
    def average_rating(self):
        """Calcule la note moyenne des avis"""
        avg = self.reviews.aggregate(avg_rating=Avg('rating'))['avg_rating']
        return round(avg, 1) if avg else 0.0
    
    @property
    def ratings_count(self):
        """Nombre total d'avis"""
        return self.reviews.count()
    
    @property
    def size_formatted(self):
        """Taille formatée (KB, MB)"""
        if self.size_bytes < 1024:
            return f"{self.size_bytes} B"
        elif self.size_bytes < 1024 * 1024:
            return f"{self.size_bytes / 1024:.1f} KB"
        else:
            return f"{self.size_bytes / (1024 * 1024):.1f} MB"


class AppScreenshot(models.Model):
    """Screenshots de l'application"""
    
    DEVICE_TYPES = [
        ('phone', 'Téléphone'),
        ('tablet', 'Tablette'),
        ('desktop', 'Bureau'),
    ]
    
    app = models.ForeignKey(MiniApp, on_delete=models.CASCADE, related_name='screenshots')
    image = models.ImageField(upload_to='screenshots/')
    device_type = models.CharField(max_length=10, choices=DEVICE_TYPES, default='phone')
    order = models.IntegerField(default=0)
    caption = models.CharField(max_length=200, blank=True)
    
    class Meta:
        ordering = ['order']
    
    def __str__(self):
        return f"Screenshot {self.order} - {self.app.name}"


class AppReview(models.Model):
    """Avis utilisateur sur une application"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    app = models.ForeignKey(MiniApp, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='app_reviews')
    
    rating = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Note de 1 à 5"
    )
    title = models.CharField(max_length=100, blank=True)
    content = models.TextField(blank=True)
    
    # Réponse du développeur
    developer_response = models.TextField(blank=True)
    developer_response_date = models.DateTimeField(null=True, blank=True)
    
    # Métadonnées
    app_version = models.CharField(max_length=20, blank=True, help_text="Version lors de l'avis")
    helpful_count = models.PositiveIntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
        unique_together = ['app', 'user']  # Un seul avis par utilisateur par app
    
    def __str__(self):
        return f"Avis {self.rating}★ - {self.app.name} par {self.user.username}"


class AppVersion(models.Model):
    app = models.ForeignKey(MiniApp, on_delete=models.CASCADE, related_name='versions')
    version_number = models.CharField(max_length=20, help_text="ex: 1.0.0")
    zip_file = models.FileField(upload_to='apps_zips/')
    release_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.app.name} v{self.version_number}"
