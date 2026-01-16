#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ondes_backend.settings')
django.setup()

from store.models import Category

count = Category.objects.count()
print(f'Catégories existantes: {count}')

if count == 0:
    categories = [
        ('games', 'Jeux', '#FF2D55'),
        ('social', 'Réseaux sociaux', '#007AFF'),
        ('productivity', 'Productivité', '#34C759'),
        ('entertainment', 'Divertissement', '#FF9500'),
        ('education', 'Éducation', '#5856D6'),
        ('utilities', 'Utilitaires', '#8E8E93'),
        ('lifestyle', 'Style de vie', '#FF2D55'),
        ('finance', 'Finance', '#30D158'),
        ('health', 'Santé et forme', '#FF375F'),
        ('sports', 'Sports', '#32ADE6'),
        ('travel', 'Voyages', '#FFD60A'),
        ('food', 'Cuisine et boissons', '#FF9F0A'),
        ('shopping', 'Shopping', '#BF5AF2'),
        ('music', 'Musique', '#FF2D55'),
        ('photo', 'Photo et vidéo', '#64D2FF'),
        ('weather', 'Météo', '#30D5C8'),
        ('news', 'Actualités', '#FF453A'),
        ('books', 'Livres', '#FF9F0A'),
        ('business', 'Business', '#0A84FF'),
        ('developer', 'Développement', '#5E5CE6'),
        ('navigation', 'Navigation', '#32D74B'),
        ('kids', 'Enfants', '#FF6482'),
        ('art', 'Art et design', '#BF5AF2'),
        ('medical', 'Médecine', '#FF375F'),
        ('reference', 'Références', '#64D2FF'),
    ]
    
    for slug, name, color in categories:
        Category.objects.create(slug=slug, name=name, color=color)
        print(f'  + {name}')
    
    print(f'\n{len(categories)} catégories créées!')
else:
    print('Catégories déjà présentes:')
    for cat in Category.objects.all():
        print(f'  - {cat.name} ({cat.slug})')
