import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import json
import os
import copy

print("Preparing to train the real medical model...")

# 1. Load the Base Model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

model = torch.load("model.pt", map_location=device, weights_only=False)

# 2. Check the Dataset for Classes
train_dir = 'data/train'
val_dir = 'data/val'
if not os.path.exists(train_dir):
    print(f"Error: {train_dir} not found. Ensure fetch_skin_data.py has finished running!")
    exit(1)

# We use ImageFolder just to get the classes initially
temp_dataset = datasets.ImageFolder(train_dir)
class_names = temp_dataset.classes
num_classes = len(class_names)
print(f"Found {num_classes} classes in your dataset: {class_names}")

# Save the class names to a JSON file so the backend API knows what to predict!
with open("classes.json", "w") as f:
    json.dump(class_names, f)
print("Saved classes.json for the backend API.")

# 3. Adapt the Model Architecture
# Our base model.pt has 4 output features. If the new dataset has a different number,
# we MUST replace the final layer so PyTorch doesn't crash during training.
current_out_features = model.classifier[1].out_features
if current_out_features != num_classes:
    print(f"Adapting model output layer from {current_out_features} to {num_classes} classes...")
    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, num_classes)
    model = model.to(device)

# 4. Freeze backbone for initial phase (fine-tune classifier only first)
print("Phase 1: Freezing backbone, training classifier head only...")
for param in model.features.parameters():
    param.requires_grad = False

# 5. Prepare the Image Transformations
train_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

val_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# Reload dataset with transformations
train_data = datasets.ImageFolder(train_dir, transform=train_transforms)
train_loader = DataLoader(train_data, batch_size=32, shuffle=True, num_workers=2)

val_data = datasets.ImageFolder(val_dir, transform=val_transforms)
val_loader = DataLoader(val_data, batch_size=32, shuffle=False, num_workers=2)

print(f"Training images: {len(train_data)} | Validation images: {len(val_data)}")

# 6. Training Configuration
criterion = nn.CrossEntropyLoss()
total_epochs = 15
patience = 4  # Early stopping: stop if no improvement for 4 epochs

best_val_acc = 0.0
best_model_weights = None
epochs_no_improve = 0


def evaluate(model, loader, criterion):
    """Run validation and return average loss + accuracy."""
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            running_loss += loss.item()
            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    avg_loss = running_loss / len(loader)
    accuracy = 100.0 * correct / total
    return avg_loss, accuracy


# ================================================================
# Phase 1: Train only the classifier head (backbone frozen)
# ================================================================
phase1_epochs = 5
optimizer = optim.Adam(model.classifier.parameters(), lr=0.001)
scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=3, gamma=0.5)

print(f"\n{'='*60}")
print(f"Phase 1: Training classifier head ({phase1_epochs} epochs)")
print(f"{'='*60}")

for epoch in range(phase1_epochs):
    model.train()
    running_loss = 0.0
    for step, (images, labels) in enumerate(train_loader):
        images, labels = images.to(device), labels.to(device)

        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        if step % 10 == 0:
            print(f"  Epoch [{epoch+1}/{phase1_epochs}], Step [{step}/{len(train_loader)}], Loss: {loss.item():.4f}")

    scheduler.step()
    train_loss = running_loss / len(train_loader)
    val_loss, val_acc = evaluate(model, val_loader, criterion)
    current_lr = optimizer.param_groups[0]['lr']
    print(f"  --- Epoch {epoch+1} | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.1f}% | LR: {current_lr:.6f} ---")

    if val_acc > best_val_acc:
        best_val_acc = val_acc
        best_model_weights = copy.deepcopy(model.state_dict())


# ================================================================
# Phase 2: Unfreeze backbone + fine-tune everything with lower LR
# ================================================================
print(f"\n{'='*60}")
print(f"Phase 2: Fine-tuning full model ({total_epochs - phase1_epochs} epochs)")
print(f"{'='*60}")

for param in model.features.parameters():
    param.requires_grad = True

optimizer = optim.Adam(model.parameters(), lr=0.0001)  # Lower LR for full fine-tuning
scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=total_epochs - phase1_epochs)
epochs_no_improve = 0

for epoch in range(phase1_epochs, total_epochs):
    model.train()
    running_loss = 0.0
    for step, (images, labels) in enumerate(train_loader):
        images, labels = images.to(device), labels.to(device)

        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        if step % 10 == 0:
            print(f"  Epoch [{epoch+1}/{total_epochs}], Step [{step}/{len(train_loader)}], Loss: {loss.item():.4f}")

    scheduler.step()
    train_loss = running_loss / len(train_loader)
    val_loss, val_acc = evaluate(model, val_loader, criterion)
    current_lr = optimizer.param_groups[0]['lr']
    print(f"  --- Epoch {epoch+1} | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.1f}% | LR: {current_lr:.6f} ---")

    if val_acc > best_val_acc:
        best_val_acc = val_acc
        best_model_weights = copy.deepcopy(model.state_dict())
        epochs_no_improve = 0
        print(f"  ★ New best validation accuracy: {best_val_acc:.1f}%")
    else:
        epochs_no_improve += 1
        print(f"  No improvement for {epochs_no_improve}/{patience} epochs.")

    if epochs_no_improve >= patience:
        print(f"\n  Early stopping triggered! No improvement for {patience} epochs.")
        break


# 7. Restore the best model weights and save
if best_model_weights is not None:
    model.load_state_dict(best_model_weights)
    print(f"\nRestored best model weights (Val Acc: {best_val_acc:.1f}%)")

torch.save(model, "model_trained.pt")
print(f"\n{'='*60}")
print(f"Training complete! Best Validation Accuracy: {best_val_acc:.1f}%")
print(f"Model saved as 'model_trained.pt'")
print(f"Rename 'model_trained.pt' to 'model.pt' to use it in your live app.")
print(f"{'='*60}")
