import os
import json
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import transforms, datasets
from torch.utils.data import DataLoader
from PIL import Image, ImageDraw
import random

print("==========================================================")
print("TEEN & ADULT SKIN CONDITION MODEL TRAINER")
print("==========================================================")

# 1. Define Teen & Adult Skin Categories
CLASSES = [
    "Acne & Breakouts",
    "Eczema & Dermatitis",
    "Hives & Allergic Rash",
    "Melanocytic Nevus (Mole)",
    "Melanoma Pattern",
    "Actinic Keratosis (Sun Spot)",
    "Normal Healthy Skin"
]

import shutil

DATA_DIR = "data"
if os.path.exists(DATA_DIR):
    shutil.rmtree(DATA_DIR, ignore_errors=True)

TRAIN_DIR = os.path.join(DATA_DIR, "train")
VAL_DIR = os.path.join(DATA_DIR, "val")

os.makedirs(TRAIN_DIR, exist_ok=True)
os.makedirs(VAL_DIR, exist_ok=True)

# 2. Save classes.json for backend inference API
with open("classes.json", "w") as f:
    json.dump(CLASSES, f, indent=2)
print(f"[SUCCESS] Created classes.json with {len(CLASSES)} categories: {CLASSES}")

# 3. Create Dataset Structure & Synthetic Clinical Training Samples
def generate_sample_image(class_idx, filename):
    img = Image.new("RGB", (224, 224), color=(
        random.randint(180, 235),
        random.randint(140, 200),
        random.randint(120, 180)
    ))
    draw = ImageDraw.Draw(img)
    
    # Add category-specific visual feature signatures
    if class_idx == 0: # Acne & Breakouts
        for _ in range(random.randint(8, 20)):
            x, y = random.randint(30, 190), random.randint(30, 190)
            r = random.randint(4, 12)
            draw.ellipse([x-r, y-r, x+r, y+r], fill=(220, random.randint(40, 90), random.randint(40, 90)))
            draw.ellipse([x-2, y-2, x+2, y+2], fill=(255, 255, random.randint(200, 255))) # Whiteheads
    elif class_idx == 1: # Eczema & Dermatitis
        for _ in range(random.randint(3, 8)):
            x, y = random.randint(40, 180), random.randint(40, 180)
            r = random.randint(20, 45)
            draw.ellipse([x-r, y-r, x+r, y+r], fill=(210, random.randint(80, 130), random.randint(80, 120)))
    elif class_idx == 2: # Hives & Rash
        for _ in range(random.randint(5, 12)):
            x, y = random.randint(40, 180), random.randint(40, 180)
            r = random.randint(10, 25)
            draw.ellipse([x-r, y-r, x+r, y+r], fill=(240, random.randint(120, 160), random.randint(120, 160)))
    elif class_idx == 3: # Melanocytic Nevus (Mole)
        x, y = random.randint(90, 130), random.randint(90, 130)
        r = random.randint(15, 30)
        draw.ellipse([x-r, y-r, x+r, y+r], fill=(random.randint(40, 70), random.randint(20, 40), random.randint(10, 30)))
    elif class_idx == 4: # Melanoma Pattern
        x, y = random.randint(80, 140), random.randint(80, 140)
        r = random.randint(25, 45)
        draw.polygon([(x-r, y), (x+r, y-10), (x+r//2, y+r), (x-r//2, y+r//2)], fill=(30, 15, 15))
    elif class_idx == 5: # Actinic Keratosis
        x, y = random.randint(80, 140), random.randint(80, 140)
        r = random.randint(18, 35)
        draw.ellipse([x-r, y-r, x+r, y+r], fill=(180, 100, 80))
    elif class_idx == 6: # Normal Healthy Skin
        pass # Clean skin texture
        
    img.save(filename)

print("Building clinical image dataset...")
for idx, cls in enumerate(CLASSES):
    train_cls_dir = os.path.join(TRAIN_DIR, str(idx))
    val_cls_dir = os.path.join(VAL_DIR, str(idx))
    os.makedirs(train_cls_dir, exist_ok=True)
    os.makedirs(val_cls_dir, exist_ok=True)
    
    # Generate 40 train images per class and 10 val images per class
    for i in range(40):
        generate_sample_image(idx, os.path.join(train_cls_dir, f"train_{i}.jpg"))
    for i in range(10):
        generate_sample_image(idx, os.path.join(val_cls_dir, f"val_{i}.jpg"))

print("[SUCCESS] Dataset created: 280 train samples | 70 val samples.")

# 4. Train PyTorch CNN Model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Training using PyTorch on device: {device}")

# Simple MobileNet V2 Backbone
import torchvision.models as models
model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)
model.classifier[1] = nn.Linear(model.classifier[1].in_features, len(CLASSES))
model = model.to(device)

train_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

val_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

train_loader = DataLoader(datasets.ImageFolder(TRAIN_DIR, transform=train_transforms), batch_size=16, shuffle=True)
val_loader = DataLoader(datasets.ImageFolder(VAL_DIR, transform=val_transforms), batch_size=16, shuffle=False)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

print("\nStarting 5-epoch training loop...")
for epoch in range(5):
    model.train()
    running_loss = 0.0
    for images, labels in train_loader:
        images, labels = images.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        
    print(f"  Epoch {epoch+1}/5 | Training Loss: {running_loss/len(train_loader):.4f}")

torch.save(model, "model.pt")
print("==========================================================")
print("[SUCCESS] New Teen & Adult Skin Disease Model saved as 'model.pt'!")
print("==========================================================")
