import requests
import os
import pandas as pd
import hashlib
import time
import random
import urllib.parse
import numpy as np

os.makedirs('images', exist_ok=True)

# PEXELS API KEY - REQUIRED! Get free: https://www.pexels.com/api/
PEXELS_API_KEY = 'wP5k3QZxkEDBEzRF13XXZvu1uiF2VehkwQB6u2BLPtEKw1YZ8CcEwGbU'  # ← REPLACE THIS!

TIMEOUT = 30

print("Loading CSV...")
df = pd.read_csv('items.csv')
print(f"Loaded {len(df)} rows")

# Group by article for reuse
article_groups = df.groupby('article').groups

if 'image_id' not in df.columns:
    df['image_id'] = np.nan
df['image_id'] = df['image_id'].astype('string').fillna(np.nan)

print("Unique articles:", len(article_groups))

article_to_image_id = {}
downloaded_hashes = set()
next_image_id = 0

while os.path.exists(f'images/{next_image_id}.jpg'):
    next_image_id += 1

print(f"Starting image_id: {next_image_id}")

headers = {'Authorization': PEXELS_API_KEY}

for article, indices in article_groups.items():
    print(f"\n[{len(indices)}x] {article}")
    
    image_id = article_to_image_id.get(article)
    if image_id is not None and os.path.exists(f'images/{image_id}.jpg'):
        print(f"  Reuse {image_id}")
        for idx in indices:
            df.at[idx, 'image_id'] = image_id
        continue
    
    # Pexels search - BEST MATCH (page=1, first result)
    params = {
        'query': article,
        'per_page': 1,  # ONLY first (best) result
        'page': 1       # Fixed for consistency
    }
    
    img_url = None
    max_retries = 3
    for attempt in range(max_retries):
        try:
            resp = requests.get(
                'https://api.pexels.com/v1/search',
                params=params,
                headers=headers,
                timeout=TIMEOUT
            )
            resp.raise_for_status()
            photos = resp.json().get('photos', [])
            
            if photos:
                # BEST MATCH: First photo's ORIGINAL quality
                img_url = photos[0]['src']['original']
                print(f"  Best match found ✓")
                break
            else:
                print(f"  No photos")
                break
                
        except requests.exceptions.Timeout:
            print(f"  Timeout {attempt+1}/3")
            time.sleep(2 ** attempt)
        except requests.exceptions.HTTPError as e:
            status = resp.status_code
            if status == 401:
                print("❌ BAD API KEY - https://www.pexels.com/api/")
                exit(1)
            print(f"  HTTP {status}")
            break
        except Exception as e:
            print(f"  Error: {e}")
            break
    
    # Hash check + download
    if img_url:
        img_hash = None
        for h_attempt in range(max_retries):
            try:
                h_resp = requests.get(img_url, stream=True, timeout=TIMEOUT)
                h_resp.raise_for_status()
                img_hash = hashlib.md5(h_resp.content).hexdigest()
                break
            except:
                time.sleep(1)
        
        if img_hash and img_hash not in downloaded_hashes:
            downloaded_hashes.add(img_hash)
            
            filename = f"images/{next_image_id}.jpg"
            success = False
            for dl_attempt in range(max_retries):
                try:
                    dl_resp = requests.get(img_url, stream=True, timeout=TIMEOUT)
                    dl_resp.raise_for_status()
                    with open(filename, 'wb') as f:
                        for chunk in dl_resp.iter_content(1024):
                            f.write(chunk)
                    
                    image_id = str(next_image_id)
                    article_to_image_id[article] = image_id
                    for idx in indices:
                        df.at[idx, 'image_id'] = image_id
                    
                    print(f"  → {image_id} ({len(indices)} items)")
                    next_image_id += 1
                    while os.path.exists(f'images/{next_image_id}.jpg'):
                        next_image_id += 1
                    success = True
                    break
                except Exception as e:
                    print(f"  DL fail {dl_attempt+1}: {e}")
                    time.sleep(2)
            
            if not success:
                print("  DL failed")
        else:
            print("  Duplicate hash")
    else:
        # Shared fallback 0
        shared_file = 'images/0.jpg'
        if not os.path.exists(shared_file):
            print("  Creating shared 0.jpg")
            # Use any previous image as fallback or skip
        
        image_id = '0'
        article_to_image_id[article] = image_id
        for idx in indices:
            df.at[idx, 'image_id'] = image_id
        print(f"  → SHARED 0 ({len(indices)} items)")
    
    time.sleep(3)  # Pexels courtesy

print("\nSAVING...")
print("image_id sample:", df['image_id'].dropna().head().tolist())
df.to_csv('items.csv', index=False)
print("✅ SAVED!")

print(f"Unique images: {next_image_id}, Shared: {df['image_id'].eq('0').sum()}")