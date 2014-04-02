import processing.video.*;
import java.util.Arrays;
import processing.serial.*;
import gab.opencv.*;

Serial myPort;

final float rWeight = 0.2989;
final float gWeight = 0.5866;
final float bWeight = 0.1145;

final int asciiWidth = 65;
final int asciiHeight = 32;
final int imageWidth = 640;
final int imageHeight = 480;

OpenCV opencv;
Capture cam;
PFont f;

// This is in greyscale order
final String palette = "   ...',;:clodxkO0KXNWM";

final int textHeight = 14;

ArrayList<String> ascii;

void setup() {
  size(imageWidth*2, imageHeight);
  f = createFont("Courier", textHeight, true);
  textFont(f);
  cam = new Capture(this, imageWidth, imageHeight, 30);
  cam.start();
  frameRate(10);
  
  opencv = new OpenCV(this, imageWidth, imageHeight);
//  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  
//  myPort = new Serial(this, "/dev/cu.usbserial-AH00ZNA4", 115200);
}

int counter = 0;

void draw() {
  if (cam.available()) {
    background(255);
    cam.read();
    opencv.loadImage(cam);
    opencv.contrast(map(mouseX, 0, width, 0, 4));
//    opencv.adaptiveThreshold(591, 1);
    PImage img = opencv.getOutput();
    
    image(img, 0, 0);
    
    fill(0);
    ArrayList<String> ascii = toAscii(img);

    int textY = 0;
    for (String row : ascii) {
      textY += textHeight;
      text(row, imageWidth, textY);
    }
  }
}

ArrayList<String> toAscii(PImage img) {
  ascii = new ArrayList<String>(asciiWidth);

  img.loadPixels();
  
  // Go through the image as blocks
  // the blocks can overlap a little because of rounding, this is ok
  for (int row = 0; row < asciiHeight; row++) {
    StringBuilder asciiRow = new StringBuilder(asciiWidth);
    
    int rowTop = (int)Math.round(1.0*row*img.height/asciiHeight);
    int rowBottom = (int)Math.round(1.0*(row+1)*img.height/asciiHeight);
    if (row == asciiHeight - 1) {
      rowBottom = img.height - 1;
    }
    
    for (int col = 0; col < asciiWidth; col++) {
      int colLeft = (int)Math.round(1.0*col*img.width/asciiWidth);
      int colRight = (int)Math.round(1.0*(col+1)*img.width/asciiWidth);
      if (col == asciiHeight - 1) {
        colRight = img.width - 1;
      }
      
      // rowTop, rowBottom, colLeft, colRight define the pixel
      // boundaries of the box corresponding to our ascii
      
      // Now we are ready to take the average value
      double lum = 0;
      int count = 0;
      
      for (int i = rowTop; i < rowBottom; i++) {
        for (int j = colLeft; j < colRight; j++) {
          color p = img.pixels[i*img.width+j];
          float r = red(p) / 255.0;
          float g = green(p) / 255.0;
          float b = blue(p) / 255.0;
          lum += rWeight*r + gWeight*g + bWeight*b;
          count++;
        }
      }
      
      lum = (1 - lum/count);
      
      // lum is between 0 and 1, and we can map it into ascii
      int paletteIndex = (int)Math.round(lum*(palette.length()-1));
      asciiRow.append(palette.charAt(paletteIndex));
    }
    asciiRow.append("\n");
    ascii.add(asciiRow.toString());
  }
  
  return ascii;
}

void mousePressed() {
//  if (ascii != null) {
//    println("typing portrait...");
//    for (String s : ascii) {
//      // make sure each row takes at least 15 seconds
//      int m = millis();
//      myPort.write(s);
//      while (millis() < m + 12*1000);
//      myPort.write(0x0a);
//    }
//    println("done");
//  }
}

