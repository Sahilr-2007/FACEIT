import torch
import torchvision.models as models
import torch.nn as nn

import json
import os

print("Downloading MobileNetV2 architecture...")
model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)

num_classes = 4
if os.path.exists("classes.json"):
    with open("classes.json", "r") as f:
        classes = json.load(f)
        num_classes = len(classes)
        print(f"Loaded {num_classes} classes from classes.json")

print(f"Modifying classifier for {num_classes} skin classes...")
num_ftrs = model.classifier[1].in_features
model.classifier[1] = nn.Linear(num_ftrs, num_classes)

# We want the model to output raw logits (which our FastAPI softmax will convert to probabilities)
model.eval()

# Save the entire model architecture and weights to model.pt
print("Saving model to model.pt...")
torch.save(model, "model.pt")

print("Done! The base PyTorch model is ready.")
