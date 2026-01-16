"""
Migration pour supprimer les modèles Friendship de l'app store.
Les modèles sont déplacés vers l'app 'friends'.
"""
from django.db import migrations


class Migration(migrations.Migration):
    
    dependencies = [
        ('store', '0004_friendship_friendshipactivity'),
    ]
    
    operations = [
        # Supprimer FriendshipActivity d'abord (dépend de Friendship)
        migrations.DeleteModel(
            name='FriendshipActivity',
        ),
        # Puis supprimer Friendship
        migrations.DeleteModel(
            name='Friendship',
        ),
    ]
