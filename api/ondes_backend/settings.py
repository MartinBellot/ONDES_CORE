from pathlib import Path
from decouple import config, Csv
import os

BASE_DIR = Path(__file__).resolve().parent.parent

# ==================== CORE ====================
SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1', cast=Csv())

INSTALLED_APPS = [
    'daphne',  # Django Channels ASGI server
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'channels',  # Django Channels
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'store',
    'friends',
    'social',
    'chat',  # Chat E2EE module
    'genesis',  # GENESIS — AI Mini-App creator
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '60/minute',
        'user': '200/minute',
        'auth': '10/minute',
        'download': '30/minute',
    },
}

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware', # First
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'ondes_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'ondes_backend.wsgi.application'
ASGI_APPLICATION = 'ondes_backend.asgi.application'

# Channel Layers Configuration
_redis_url = config('REDIS_URL', default='')
if _redis_url:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [_redis_url],
            },
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer"
        }
    }

# Database — SQLite (dev) or PostgreSQL (prod) via env
DATABASES = {
    'default': {
        'ENGINE': config('DATABASE_ENGINE', default='django.db.backends.sqlite3'),
        'NAME': config('DATABASE_NAME', default=str(BASE_DIR / 'db.sqlite3')),
        'USER': config('DATABASE_USER', default=''),
        'PASSWORD': config('DATABASE_PASSWORD', default=''),
        'HOST': config('DATABASE_HOST', default=''),
        'PORT': config('DATABASE_PORT', default=''),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'fr-fr'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Media Configuration for Apps Zips and Icons
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ==================== CORS ====================
_cors_origins = config('CORS_ALLOWED_ORIGINS', default='')
if DEBUG and not _cors_origins:
    CORS_ALLOW_ALL_ORIGINS = True
else:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = [o.strip() for o in _cors_origins.split(',') if o.strip()]

# ==================== SECURITY HEADERS (prod) ====================
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# ==================== LOGGING ====================
# Créer le dossier logs/ si absent (dev local + Docker)
LOGS_DIR = BASE_DIR / 'logs'
os.makedirs(LOGS_DIR, exist_ok=True)

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': LOGS_DIR / 'ondes.log',
            'maxBytes': 10 * 1024 * 1024,  # 10 MB par fichier
            'backupCount': 5,
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'WARNING',
            'propagate': False,
        },
        'store': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'social': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'friends': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'chat': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'genesis': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
    },
}

# ==================== GENESIS / LLM ====================
# The anthropic SDK reads ANTHROPIC_API_KEY from the environment automatically.
# You may also set it explicitly here if needed:
# ANTHROPIC_API_KEY = config('ANTHROPIC_API_KEY', default='')

# ==================== STRIPE ====================
STRIPE_SECRET_KEY = config('STRIPE_SECRET_KEY', default='')
STRIPE_WEBHOOK_SECRET = config('STRIPE_WEBHOOK_SECRET', default='')
STRIPE_PRO_MONTHLY_PRICE_ID = config('STRIPE_PRO_MONTHLY_PRICE_ID', default='')
STRIPE_PRO_YEARLY_PRICE_ID = config('STRIPE_PRO_YEARLY_PRICE_ID', default='')
STRIPE_CREDIT_PACK_PRICE_ID = config('STRIPE_CREDIT_PACK_PRICE_ID', default='')

# ==================== FILE UPLOAD LIMITS ====================
DATA_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50 MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50 MB
MAX_ZIP_UPLOAD_SIZE = 100 * 1024 * 1024  # 100 MB for app zips
