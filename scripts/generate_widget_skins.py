import os
import json
from PIL import Image

# Configuration
SOURCE_DIR = 'assets/skins'
ANDROID_DRAWABLE_DIR = 'android/app/src/main/res/drawable'
IOS_ASSETS_DIR = 'ios/AmberWidget/Assets.xcassets'

# Ensure directories exist
os.makedirs(ANDROID_DRAWABLE_DIR, exist_ok=True)
os.makedirs(IOS_ASSETS_DIR, exist_ok=True)

def process_image(filename, index):
    source_path = os.path.join(SOURCE_DIR, filename)
    try:
        img = Image.open(source_path).convert('RGBA')
        w, h = img.size
        
        # Crop 10% from top and bottom to remove text
        # Original: 1024x1366
        # Crop top 136px, bottom 136px
        top_crop = int(h * 0.1)
        bottom_crop = int(h * 0.9)
        img_cropped = img.crop((0, top_crop, w, bottom_crop))
        
        # --- Android ---
        # Save as widget_skin_contrast_XX.png
        # Target size? Android widgets scale, but let's keep it decent resolution.
        # Maybe scale down a bit to save size? 
        # Cropped height approx 1092. Let's keep width 1024 or scale to 800? 
        # Let's keep relatively high quality: resize to width 720 (hdpi/xhdpiish)
        # Ratio is 1024 / (1366*0.8) ~= 1024 / 1092 ~= 0.93
        
        android_width = 720
        ratio = android_width / w
        android_height = int((bottom_crop - top_crop) * ratio)
        
        img_android = img_cropped.resize((android_width, android_height), Image.Resampling.LANCZOS)
        
        android_filename = f"widget_skin_contrast_{index:02d}.png"
        android_path = os.path.join(ANDROID_DRAWABLE_DIR, android_filename)
        img_android.save(android_path, 'PNG')
        print(f"Generated Android: {android_filename}")

        # --- iOS ---
        # Generate imageset
        ios_name = f"contrast{index:02d}"
        imageset_dir = os.path.join(IOS_ASSETS_DIR, f"{ios_name}.imageset")
        os.makedirs(imageset_dir, exist_ok=True)
        
        # Sizes:
        # 3x: max width needed. Large widget is ~360pt -> 1080px.
        # Let's use 1080px width for 3x.
        ios_w_3x = 1080
        ratio_3x = ios_w_3x / w
        ios_h_3x = int((bottom_crop - top_crop) * ratio_3x)
        img_3x = img_cropped.resize((ios_w_3x, ios_h_3x), Image.Resampling.LANCZOS)
        img_3x.save(os.path.join(imageset_dir, f"{ios_name}@3x.png"), 'PNG')
        
        # 2x: 720px
        ios_w_2x = 720
        ratio_2x = ios_w_2x / w
        ios_h_2x = int((bottom_crop - top_crop) * ratio_2x)
        img_2x = img_cropped.resize((ios_w_2x, ios_h_2x), Image.Resampling.LANCZOS)
        img_2x.save(os.path.join(imageset_dir, f"{ios_name}@2x.png"), 'PNG')
        
        # 1x: 360px
        ios_w_1x = 360
        ratio_1x = ios_w_1x / w
        ios_h_1x = int((bottom_crop - top_crop) * ratio_1x)
        img_1x = img_cropped.resize((ios_w_1x, ios_h_1x), Image.Resampling.LANCZOS)
        img_1x.save(os.path.join(imageset_dir, f"{ios_name}@1x.png"), 'PNG')

        # Contents.json
        contents = {
            "images": [
                {"start": "xscale", "scale": "1x", "idiom": "universal", "filename": f"{ios_name}@1x.png"},
                {"start": "xscale", "scale": "2x", "idiom": "universal", "filename": f"{ios_name}@2x.png"},
                {"start": "xscale", "scale": "3x", "idiom": "universal", "filename": f"{ios_name}@3x.png"}
            ],
            "info": {"version": 1, "author": "xcode"}
        }
        with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"Generated iOS: {ios_name}.imageset")

    except Exception as e:
        print(f"Error processing {filename}: {e}")

def main():
    if not os.path.exists(SOURCE_DIR):
        print(f"Source directory not found: {SOURCE_DIR}")
        return

    files = sorted([f for f in os.listdir(SOURCE_DIR) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
    
    if not files:
        print("No image files found in assets/skins")
        return

    print(f"Found {len(files)} source images.")
    for i, filename in enumerate(files):
        # 1-based index for naming
        process_image(filename, i + 1)
        
    print("Done!")

if __name__ == "__main__":
    main()
