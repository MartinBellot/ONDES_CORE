import os
import sys
import django
import zipfile
from django.core.files.base import ContentFile

# Setup Django Environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ondes_backend.settings')
django.setup()

from store.models import MiniApp, AppVersion

def create_meteo_app():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    app_source_dir = os.path.join(base_dir, 'examples', 'meteo-app')
    
    print(f"Zipping content from {app_source_dir}...")
    
    # Create a ZIP definition in memory? Better to write a temp file to ensure it's valid
    zip_path = os.path.join(base_dir, 'examples', 'meteo_bundle.zip')
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(app_source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                # Store relative to app_source_dir so index.html is at root of zip
                arcname = os.path.relpath(file_path, app_source_dir)
                zipf.write(file_path, arcname)
    
    print(f"Created zip at {zip_path}")
    
    # Database Operations
    bundle_id = "com.ondes.meteo"
    app, created = MiniApp.objects.get_or_create(
        bundle_id=bundle_id,
        defaults={
            'name': 'Meteo App',
            'description': 'Une application météo utilisant le GPS natif.'
        }
    )
    
    if created:
        print(f"Created new MiniApp: {app.name}")
    else:
        print(f"Found existing MiniApp: {app.name}")

    # Read the zip file to save it to the model
    with open(zip_path, 'rb') as f:
        zip_content = f.read()
        
    # Create Version
    version_number = "1.0.0"
    
    # Check if this version exists
    if AppVersion.objects.filter(app=app, version_number=version_number).exists():
        print("Version 1.0.0 already exists. Skipping creation.")
    else:
        version = AppVersion(
            app=app,
            version_number=version_number,
            release_notes="Initial release with GPS support."
        )
        version.zip_file.save(f"{bundle_id}_v{version_number}.zip", ContentFile(zip_content))
        version.save()
        print(f"Created AppVersion {version.version_number}")
        
    # Cleanup
    if os.path.exists(zip_path):
        os.remove(zip_path)
        print("Cleaned up temporary zip file.")

if __name__ == "__main__":
    create_meteo_app()
