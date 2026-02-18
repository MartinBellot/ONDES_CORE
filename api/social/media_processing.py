"""
Utilitaires de traitement média pour Ondes Social.
- Compression d'images (PIL/Pillow)
- Conversion HLS pour vidéos (FFmpeg)
"""
import os
import subprocess
import uuid
import tempfile
import shutil
from pathlib import Path
from PIL import Image
from django.conf import settings
from django.core.files.base import ContentFile
import io
import logging

logger = logging.getLogger('social')


class ImageProcessor:
    """
    Processeur d'images avec compression et génération de miniatures.
    """
    
    # Paramètres de compression
    MAX_WIDTH = 1920
    MAX_HEIGHT = 1920
    THUMBNAIL_SIZE = (400, 400)
    QUALITY = 85  # Qualité JPEG (0-100)
    
    @staticmethod
    def compress_image(image_path, output_path=None, max_width=None, max_height=None, quality=None):
        """
        Compresse une image en conservant le ratio.
        
        Args:
            image_path: Chemin vers l'image source
            output_path: Chemin de sortie (optionnel, génère un nouveau fichier)
            max_width: Largeur maximale
            max_height: Hauteur maximale
            quality: Qualité de compression (0-100)
        
        Returns:
            tuple: (output_path, width, height, file_size)
        """
        max_width = max_width or ImageProcessor.MAX_WIDTH
        max_height = max_height or ImageProcessor.MAX_HEIGHT
        quality = quality or ImageProcessor.QUALITY
        
        with Image.open(image_path) as img:
            # Convertir en RGB si nécessaire (pour les PNG avec transparence)
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # Calculer les nouvelles dimensions en conservant le ratio
            width, height = img.size
            ratio = min(max_width / width, max_height / height)
            
            if ratio < 1:
                new_width = int(width * ratio)
                new_height = int(height * ratio)
                img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            else:
                new_width, new_height = width, height
            
            # Sauvegarder
            if not output_path:
                output_path = str(Path(image_path).with_suffix('.jpg'))
            
            img.save(output_path, 'JPEG', quality=quality, optimize=True)
            file_size = os.path.getsize(output_path)
            
            return output_path, new_width, new_height, file_size
    
    @staticmethod
    def create_thumbnail(image_path, output_path=None, size=None):
        """
        Crée une miniature carrée.
        
        Args:
            image_path: Chemin vers l'image source
            output_path: Chemin de sortie
            size: Tuple (width, height) ou int pour carré
        
        Returns:
            tuple: (output_path, width, height)
        """
        size = size or ImageProcessor.THUMBNAIL_SIZE
        if isinstance(size, int):
            size = (size, size)
        
        with Image.open(image_path) as img:
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # Crop carré centré
            width, height = img.size
            min_dim = min(width, height)
            left = (width - min_dim) // 2
            top = (height - min_dim) // 2
            img = img.crop((left, top, left + min_dim, top + min_dim))
            
            # Redimensionner
            img = img.resize(size, Image.Resampling.LANCZOS)
            
            if not output_path:
                name = Path(image_path).stem
                output_path = str(Path(image_path).parent / f"{name}_thumb.jpg")
            
            img.save(output_path, 'JPEG', quality=80, optimize=True)
            
            return output_path, size[0], size[1]
    
    @staticmethod
    def compress_to_bytes(image_path, max_width=None, max_height=None, quality=None):
        """
        Compresse et retourne les bytes de l'image (pour stockage Django).
        """
        max_width = max_width or ImageProcessor.MAX_WIDTH
        max_height = max_height or ImageProcessor.MAX_HEIGHT
        quality = quality or ImageProcessor.QUALITY
        
        with Image.open(image_path) as img:
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            width, height = img.size
            ratio = min(max_width / width, max_height / height)
            
            if ratio < 1:
                new_width = int(width * ratio)
                new_height = int(height * ratio)
                img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            else:
                new_width, new_height = width, height
            
            buffer = io.BytesIO()
            img.save(buffer, 'JPEG', quality=quality, optimize=True)
            buffer.seek(0)
            
            return buffer.getvalue(), new_width, new_height


class VideoProcessor:
    """
    Processeur vidéo avec conversion HLS via FFmpeg.
    """
    
    # Paramètres HLS
    HLS_SEGMENT_DURATION = 4  # secondes par segment
    VIDEO_BITRATES = [
        {'name': '360p', 'height': 360, 'bitrate': '800k', 'audio': '96k'},
        {'name': '480p', 'height': 480, 'bitrate': '1400k', 'audio': '128k'},
        {'name': '720p', 'height': 720, 'bitrate': '2800k', 'audio': '128k'},
        {'name': '1080p', 'height': 1080, 'bitrate': '5000k', 'audio': '192k'},
    ]
    
    @staticmethod
    def check_ffmpeg():
        """Vérifie si FFmpeg est installé."""
        try:
            subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    @staticmethod
    def get_video_info(video_path):
        """
        Récupère les métadonnées d'une vidéo.
        
        Returns:
            dict: {width, height, duration, bitrate, codec}
        """
        try:
            cmd = [
                'ffprobe', '-v', 'quiet', '-print_format', 'json',
                '-show_format', '-show_streams', video_path
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            import json
            data = json.loads(result.stdout)
            
            video_stream = next(
                (s for s in data.get('streams', []) if s['codec_type'] == 'video'),
                {}
            )
            
            return {
                'width': int(video_stream.get('width', 0)),
                'height': int(video_stream.get('height', 0)),
                'duration': float(data.get('format', {}).get('duration', 0)),
                'bitrate': int(data.get('format', {}).get('bit_rate', 0)),
                'codec': video_stream.get('codec_name', ''),
            }
        except Exception as e:
            logger.error(f"Error getting video info: {e}")
            return {'width': 0, 'height': 0, 'duration': 0, 'bitrate': 0, 'codec': ''}
    
    @staticmethod
    def create_thumbnail(video_path, output_path=None, time_offset=1):
        """
        Crée une miniature à partir d'une vidéo.
        
        Args:
            video_path: Chemin vers la vidéo
            output_path: Chemin de sortie pour la miniature
            time_offset: Seconde à capturer
        
        Returns:
            str: Chemin vers la miniature
        """
        if not output_path:
            output_path = str(Path(video_path).with_suffix('.jpg'))
        
        cmd = [
            'ffmpeg', '-y', '-i', video_path,
            '-ss', str(time_offset),
            '-vframes', '1',
            '-vf', 'scale=400:-1',
            '-q:v', '2',
            output_path
        ]
        
        try:
            subprocess.run(cmd, capture_output=True, check=True)
            return output_path
        except subprocess.CalledProcessError as e:
            logger.error(f"Error creating thumbnail: {e}")
            return None
    
    @staticmethod
    def convert_to_hls(video_path, output_dir, adaptive=True):
        """
        Convertit une vidéo en HLS avec streaming adaptatif.
        
        Args:
            video_path: Chemin vers la vidéo source
            output_dir: Répertoire de sortie pour les fichiers HLS
            adaptive: Si True, génère plusieurs qualités pour l'adaptive streaming
        
        Returns:
            dict: {
                'success': bool,
                'playlist': str (chemin vers le master playlist),
                'segments_dir': str,
                'error': str (si échec)
            }
        """
        if not VideoProcessor.check_ffmpeg():
            return {'success': False, 'error': 'FFmpeg not installed'}
        
        os.makedirs(output_dir, exist_ok=True)
        
        # Récupérer les infos de la vidéo
        info = VideoProcessor.get_video_info(video_path)
        source_height = info.get('height', 720)
        
        if adaptive:
            return VideoProcessor._convert_adaptive_hls(video_path, output_dir, source_height)
        else:
            return VideoProcessor._convert_single_hls(video_path, output_dir)
    
    @staticmethod
    def _convert_single_hls(video_path, output_dir):
        """Conversion HLS simple (une seule qualité)."""
        playlist_path = os.path.join(output_dir, 'playlist.m3u8')
        segment_pattern = os.path.join(output_dir, 'segment_%03d.ts')
        
        cmd = [
            'ffmpeg', '-y', '-i', video_path,
            '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
            '-c:a', 'aac', '-b:a', '128k',
            '-hls_time', str(VideoProcessor.HLS_SEGMENT_DURATION),
            '-hls_list_size', '0',
            '-hls_segment_filename', segment_pattern,
            '-f', 'hls',
            playlist_path
        ]
        
        try:
            subprocess.run(cmd, capture_output=True, check=True)
            return {
                'success': True,
                'playlist': playlist_path,
                'segments_dir': output_dir
            }
        except subprocess.CalledProcessError as e:
            return {
                'success': False,
                'error': f"FFmpeg error: {e.stderr.decode() if e.stderr else str(e)}"
            }
    
    @staticmethod
    def _convert_adaptive_hls(video_path, output_dir, source_height):
        """Conversion HLS avec streaming adaptatif multi-qualité."""
        
        # Filtrer les bitrates en fonction de la résolution source
        valid_bitrates = [
            b for b in VideoProcessor.VIDEO_BITRATES 
            if b['height'] <= source_height
        ]
        
        if not valid_bitrates:
            valid_bitrates = [VideoProcessor.VIDEO_BITRATES[0]]
        
        # Générer chaque variante
        variant_playlists = []
        
        for br in valid_bitrates:
            variant_dir = os.path.join(output_dir, br['name'])
            os.makedirs(variant_dir, exist_ok=True)
            
            playlist_path = os.path.join(variant_dir, 'playlist.m3u8')
            segment_pattern = os.path.join(variant_dir, 'segment_%03d.ts')
            
            # Calculer la largeur proportionnelle
            scale_filter = f"scale=-2:{br['height']}"
            
            cmd = [
                'ffmpeg', '-y', '-i', video_path,
                '-vf', scale_filter,
                '-c:v', 'libx264', '-preset', 'fast',
                '-b:v', br['bitrate'],
                '-c:a', 'aac', '-b:a', br['audio'],
                '-hls_time', str(VideoProcessor.HLS_SEGMENT_DURATION),
                '-hls_list_size', '0',
                '-hls_segment_filename', segment_pattern,
                '-f', 'hls',
                playlist_path
            ]
            
            try:
                subprocess.run(cmd, capture_output=True, check=True)
                variant_playlists.append({
                    'name': br['name'],
                    'height': br['height'],
                    'bitrate': br['bitrate'],
                    'playlist': playlist_path,
                    'relative_path': f"{br['name']}/playlist.m3u8"
                })
            except subprocess.CalledProcessError as e:
                logger.error(f"Error converting {br['name']}: {e}")
                continue
        
        if not variant_playlists:
            return {'success': False, 'error': 'No variants could be created'}
        
        # Créer le master playlist
        master_playlist_path = os.path.join(output_dir, 'master.m3u8')
        VideoProcessor._create_master_playlist(master_playlist_path, variant_playlists)
        
        return {
            'success': True,
            'playlist': master_playlist_path,
            'segments_dir': output_dir,
            'variants': variant_playlists
        }
    
    @staticmethod
    def _create_master_playlist(output_path, variants):
        """Crée le master playlist HLS."""
        with open(output_path, 'w') as f:
            f.write('#EXTM3U\n')
            f.write('#EXT-X-VERSION:3\n')
            
            for v in variants:
                bitrate_int = int(v['bitrate'].replace('k', '000'))
                f.write(f'#EXT-X-STREAM-INF:BANDWIDTH={bitrate_int},RESOLUTION=x{v["height"]}\n')
                f.write(f'{v["relative_path"]}\n')


def process_post_media(post_media_instance):
    """
    Traite un média de post (compression image ou conversion HLS vidéo).
    Cette fonction est appelée de manière asynchrone après l'upload.
    
    Args:
        post_media_instance: Instance de PostMedia
    """
    from .models import PostMedia
    
    media = post_media_instance
    media.processing_status = 'processing'
    media.save(update_fields=['processing_status'])
    
    try:
        original_path = media.original_file.path
        
        if media.media_type == 'image':
            # Compression de l'image
            compressed_bytes, width, height = ImageProcessor.compress_to_bytes(original_path)
            
            # Sauvegarder l'image compressée
            compressed_name = f"compressed_{uuid.uuid4().hex[:8]}.jpg"
            media.compressed_file.save(compressed_name, ContentFile(compressed_bytes), save=False)
            
            # Créer la miniature
            thumb_path, _, _ = ImageProcessor.create_thumbnail(original_path)
            if thumb_path:
                with open(thumb_path, 'rb') as f:
                    thumb_name = f"thumb_{uuid.uuid4().hex[:8]}.jpg"
                    media.thumbnail.save(thumb_name, ContentFile(f.read()), save=False)
                os.remove(thumb_path)
            
            media.width = width
            media.height = height
            media.file_size = len(compressed_bytes)
            media.processing_status = 'completed'
        
        elif media.media_type == 'video':
            # Récupérer les infos vidéo
            info = VideoProcessor.get_video_info(original_path)
            media.width = info.get('width')
            media.height = info.get('height')
            media.duration = info.get('duration')
            media.file_size = os.path.getsize(original_path)
            
            # Créer la miniature
            thumb_path = VideoProcessor.create_thumbnail(original_path)
            if thumb_path:
                with open(thumb_path, 'rb') as f:
                    thumb_name = f"thumb_{uuid.uuid4().hex[:8]}.jpg"
                    media.thumbnail.save(thumb_name, ContentFile(f.read()), save=False)
                os.remove(thumb_path)
            
            # Conversion HLS
            hls_output_dir = os.path.join(
                settings.MEDIA_ROOT,
                f"posts/{media.post.author.id}/{media.post.uuid}/hls"
            )
            
            result = VideoProcessor.convert_to_hls(original_path, hls_output_dir)
            
            if result['success']:
                # Stocker le chemin relatif du master playlist
                relative_path = os.path.relpath(result['playlist'], settings.MEDIA_ROOT)
                media.hls_playlist.name = relative_path
                media.hls_ready = True
                media.processing_status = 'completed'
            else:
                media.processing_error = result.get('error', 'Unknown error')
                media.processing_status = 'failed'
        
        media.save()
        
    except Exception as e:
        media.processing_status = 'failed'
        media.processing_error = str(e)
        media.save(update_fields=['processing_status', 'processing_error'])
        raise


def process_story_media(story_instance):
    """
    Traite le média d'une story (compression image ou conversion HLS vidéo).
    Cette fonction est appelée de manière asynchrone après la création.
    
    Args:
        story_instance: Instance de Story
    """
    from .models import Story
    
    story = story_instance
    
    try:
        original_path = story.media.path
        
        if story.media_type == 'video':
            # Conversion HLS pour les vidéos de stories
            hls_output_dir = os.path.join(
                settings.MEDIA_ROOT,
                f"stories/{story.author.id}/{story.uuid}/hls"
            )
            
            result = VideoProcessor.convert_to_hls(original_path, hls_output_dir, adaptive=False)
            
            if result['success']:
                # Stocker le chemin relatif du playlist
                relative_path = os.path.relpath(result['playlist'], settings.MEDIA_ROOT)
                story.hls_playlist.name = relative_path
                story.hls_ready = True
                story.save(update_fields=['hls_playlist', 'hls_ready'])
            else:
                logger.warning(f"Story HLS conversion failed: {result.get('error')}")
                
    except Exception as e:
        logger.error(f"Error processing story media: {e}")
