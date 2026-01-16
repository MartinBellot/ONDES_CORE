"""
Algorithme de feed local pour Ondes Social.
Le feed est calculé côté serveur mais avec une logique locale-first.
"""
from django.db.models import Q, Count, F, ExpressionWrapper, FloatField
from django.utils import timezone
from datetime import timedelta
from .models import Post, Follow, PostLike
from friends.models import Friendship


class LocalFeedAlgorithm:
    """
    Algorithme de feed local-first.
    Priorité: 
    1. Posts des amis (Friends)
    2. Posts des following
    3. Posts publics engageants
    4. Freshaîcheur temporelle
    """
    
    # Poids pour le calcul du score
    WEIGHTS = {
        'friend_post': 100.0,        # Post d'un ami
        'following_post': 50.0,      # Post de quelqu'un qu'on suit
        'public_post': 10.0,         # Post public
        'recency_factor': 2.0,       # Bonus par heure de fraîcheur (max 48h)
        'engagement_factor': 0.1,    # Bonus par interaction
        'mutual_friends': 5.0,       # Bonus par ami en commun
        'same_tags': 3.0,            # Bonus par tag en commun avec les posts likés
    }
    
    def __init__(self, user):
        self.user = user
        self._friends_ids = None
        self._following_ids = None
        self._user_liked_tags = None
    
    @property
    def friends_ids(self):
        """IDs des amis de l'utilisateur."""
        if self._friends_ids is None:
            friendships = Friendship.objects.filter(
                Q(from_user=self.user) | Q(to_user=self.user),
                status='accepted'
            ).values_list('from_user_id', 'to_user_id')
            
            ids = set()
            for from_id, to_id in friendships:
                ids.add(from_id if from_id != self.user.id else to_id)
            
            self._friends_ids = ids
        return self._friends_ids
    
    @property
    def following_ids(self):
        """IDs des utilisateurs que l'utilisateur suit."""
        if self._following_ids is None:
            self._following_ids = set(
                Follow.objects.filter(follower=self.user)
                .values_list('following_id', flat=True)
            )
        return self._following_ids
    
    @property
    def user_liked_tags(self):
        """Tags des posts likés par l'utilisateur."""
        if self._user_liked_tags is None:
            liked_posts = PostLike.objects.filter(user=self.user).values_list('post_id', flat=True)
            tags = Post.objects.filter(id__in=liked_posts).values_list('tags', flat=True)
            
            tag_set = set()
            for tag_list in tags:
                if tag_list:
                    tag_set.update(tag_list)
            
            self._user_liked_tags = tag_set
        return self._user_liked_tags
    
    def get_feed(self, limit=50, offset=0, visibility_filter=None):
        """
        Génère le feed personnalisé.
        
        Args:
            limit: Nombre de posts à retourner
            offset: Décalage pour la pagination
            visibility_filter: Filtrer par visibilité spécifique
        
        Returns:
            list[Post]: Liste de posts triés par score de pertinence
        """
        now = timezone.now()
        cutoff_date = now - timedelta(days=7)  # Posts des 7 derniers jours
        
        # Construire le queryset de base
        posts = Post.objects.filter(
            is_deleted=False,
            created_at__gte=cutoff_date
        ).select_related('author', 'author__profile').prefetch_related('media')
        
        # Filtre de visibilité
        visibility_q = Q(visibility='public')  # Toujours voir les posts publics
        
        if self.friends_ids:
            # Posts des amis (followers ou public)
            visibility_q |= Q(author_id__in=self.friends_ids, visibility__in=['public', 'followers'])
        
        if self.following_ids:
            # Posts des following (si followers ou public)
            visibility_q |= Q(author_id__in=self.following_ids, visibility__in=['public', 'followers'])
        
        # Ses propres posts
        visibility_q |= Q(author=self.user)
        
        posts = posts.filter(visibility_q)
        
        if visibility_filter:
            posts = posts.filter(visibility=visibility_filter)
        
        # Calculer les scores et trier
        scored_posts = []
        for post in posts.distinct():
            score = self._calculate_score(post, now)
            scored_posts.append((post, score))
        
        # Trier par score décroissant
        scored_posts.sort(key=lambda x: x[1], reverse=True)
        
        # Appliquer la pagination et ajouter le score aux posts
        result = []
        for post, score in scored_posts[offset:offset + limit]:
            post.relevance_score = score
            result.append(post)
        
        return result
    
    def _calculate_score(self, post, now):
        """Calcule le score de pertinence d'un post."""
        score = 0.0
        
        # 1. Relation avec l'auteur
        if post.author_id in self.friends_ids:
            score += self.WEIGHTS['friend_post']
        elif post.author_id in self.following_ids:
            score += self.WEIGHTS['following_post']
        elif post.visibility == 'public':
            score += self.WEIGHTS['public_post']
        
        # 2. Fraîcheur temporelle (décroissance sur 48h)
        age_hours = (now - post.created_at).total_seconds() / 3600
        if age_hours < 48:
            recency_score = (48 - age_hours) * self.WEIGHTS['recency_factor']
            score += recency_score
        
        # 3. Engagement
        engagement = post.likes_count + (post.comments_count * 2) + post.shares_count
        score += engagement * self.WEIGHTS['engagement_factor']
        
        # 4. Tags en commun avec les préférences
        if post.tags and self.user_liked_tags:
            common_tags = set(post.tags) & self.user_liked_tags
            score += len(common_tags) * self.WEIGHTS['same_tags']
        
        # 5. Amis en commun avec l'auteur (si pas déjà ami)
        if post.author_id not in self.friends_ids and post.author_id != self.user.id:
            author_friends = set(
                Friendship.objects.filter(
                    Q(from_user_id=post.author_id) | Q(to_user_id=post.author_id),
                    status='accepted'
                ).values_list('from_user_id', 'to_user_id')
            )
            author_friend_ids = set()
            for from_id, to_id in author_friends:
                author_friend_ids.add(from_id if from_id != post.author_id else to_id)
            
            mutual = self.friends_ids & author_friend_ids
            score += len(mutual) * self.WEIGHTS['mutual_friends']
        
        return score
    
    def get_discover_feed(self, limit=50, offset=0):
        """
        Feed de découverte (posts publics populaires d'utilisateurs non suivis).
        """
        now = timezone.now()
        cutoff_date = now - timedelta(days=3)
        
        # Exclure les posts des amis et following
        excluded_ids = self.friends_ids | self.following_ids | {self.user.id}
        
        posts = Post.objects.filter(
            is_deleted=False,
            visibility='public',
            created_at__gte=cutoff_date
        ).exclude(
            author_id__in=excluded_ids
        ).select_related('author', 'author__profile').prefetch_related('media')
        
        # Trier par engagement et fraîcheur
        scored_posts = []
        for post in posts:
            age_hours = (now - post.created_at).total_seconds() / 3600
            engagement = post.likes_count + (post.comments_count * 2) + post.views_count * 0.1
            recency = max(0, (72 - age_hours))  # Décroissance sur 72h
            score = engagement + recency
            scored_posts.append((post, score))
        
        scored_posts.sort(key=lambda x: x[1], reverse=True)
        
        result = []
        for post, score in scored_posts[offset:offset + limit]:
            post.relevance_score = score
            result.append(post)
        
        return result
    
    def get_video_feed(self, limit=20, offset=0):
        """
        Feed vidéo style TikTok (vidéos verticales populaires).
        """
        now = timezone.now()
        cutoff_date = now - timedelta(days=7)
        
        # Posts avec des vidéos
        posts = Post.objects.filter(
            is_deleted=False,
            visibility__in=['public', 'followers'],
            created_at__gte=cutoff_date,
            media__media_type='video',
            media__hls_ready=True
        ).distinct().select_related('author', 'author__profile').prefetch_related('media')
        
        # Filtre de visibilité
        visibility_q = Q(visibility='public')
        if self.friends_ids:
            visibility_q |= Q(author_id__in=self.friends_ids)
        if self.following_ids:
            visibility_q |= Q(author_id__in=self.following_ids)
        visibility_q |= Q(author=self.user)
        
        posts = posts.filter(visibility_q)
        
        # Trier par popularité et fraîcheur
        scored_posts = []
        for post in posts:
            age_hours = (now - post.created_at).total_seconds() / 3600
            engagement = (post.likes_count * 2) + post.comments_count + (post.views_count * 0.5)
            recency = max(0, (168 - age_hours))  # Décroissance sur 1 semaine
            
            # Bonus si ami ou following
            relationship_bonus = 0
            if post.author_id in self.friends_ids:
                relationship_bonus = 50
            elif post.author_id in self.following_ids:
                relationship_bonus = 25
            
            score = engagement + recency + relationship_bonus
            scored_posts.append((post, score))
        
        # Mélanger un peu d'aléatoire pour la découverte
        import random
        random.shuffle(scored_posts)
        scored_posts.sort(key=lambda x: x[1] + random.random() * 10, reverse=True)
        
        result = []
        for post, score in scored_posts[offset:offset + limit]:
            post.relevance_score = score
            result.append(post)
        
        return result
