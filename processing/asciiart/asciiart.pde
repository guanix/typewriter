import processing.video.*;
import java.util.Arrays;
import processing.serial.*;
import gab.opencv.*;
import java.awt.Rectangle;
import org.opencv.imgproc.Imgproc;

Serial myPort;

String serialDev = "/dev/cu.usbserial-AH00ZNA4";

final float rWeight = 0.2989;
final float gWeight = 0.5866;
final float bWeight = 0.1145;

final int asciiWidth = 60;
final int asciiHeight = 30;
final int imageWidth = 640;
final int imageHeight = 480;

final int buttonWidth = 100;
final int buttonHeight = 20;
final int buttonMargin = 10;

final boolean detectFaces = false, drawBlocks = false;

OpenCV opencv;
Capture cam;
PFont f;

// This is in greyscale order
final String palette = "   ...',;:clodxkO0KXNWM";

final int textHeight = 14;

ArrayList<String> ascii;

void setup() {
  size(imageWidth*2, imageHeight, P2D);
  f = createFont("Courier", textHeight, true);
  textFont(f);
  cam = new Capture(this, imageWidth, imageHeight, 30);
  cam.start();
  frameRate(10);
  
  opencv = new OpenCV(this, imageWidth, imageHeight);
//  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);

  try {  
    myPort = new Serial(this, serialDev, 115200);
    println("serial port opened");
  } catch (RuntimeException e) {
    println("serial port not present: " + e.toString());
  }

  if (detectFaces) {
    opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  }
}

int counter = 0;

void draw() {
  if (cam.available()) {
    background(255);
    cam.read();
    opencv.loadImage(cam);
    
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_RGB2Lab);
    opencv.setGray(opencv.getR());
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_Lab2RGB);
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_RGB2BGRA);
    
//    opencv.contrast(map(mouseX, 0, width, 0, 3));
//    opencv.brightness((int)Math.round(map(mouseY, 0, height, -255, 255)));
//    opencv.threshold((int)Math.round(map(mouseX, 0, width, 50, 100)));

    PImage img = opencv.getOutput();
    
    image(img, 0, 0);
    
    if (detectFaces) {
      // Do face detection
      Rectangle[] faces;
      faces = opencv.detect();
      noFill();
      stroke(0, 255, 0);
      strokeWeight(3);
      for (int i = 0; i < faces.length; i++) {
        rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
      }
    }
    
    stroke(0);
    fill(0);
    textAlign(LEFT, TOP);
    ArrayList<String> ascii = toAscii(img);

    int textY = 0;
    for (String row : ascii) {
      textY += textHeight;
      text(row, imageWidth + 10, textY);
    }

    // Draw the button
    fill(255);
    stroke(255, 0, 0);
    strokeWeight(3);
    rect(width - buttonWidth - buttonMargin, height - buttonHeight - buttonMargin,
      buttonWidth, buttonHeight);
    fill(0);
    stroke(0);
    textAlign(CENTER, CENTER);
    text("PRINT", width - buttonMargin - buttonWidth/2.0,
      height - buttonMargin - buttonHeight/2.0);
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
    
    if (drawBlocks) {
      stroke(255);
      strokeWeight(1);
      line(0, rowTop, imageWidth, rowTop);
    }
    
    for (int col = 0; col < asciiWidth; col++) {
      int colLeft = (int)Math.round(1.0*col*img.width/asciiWidth);
      int colRight = (int)Math.round(1.0*(col+1)*img.width/asciiWidth);

      if (col == asciiWidth - 1) {
        colRight = img.width - 1;
      }
      
      if (row == 0 && drawBlocks) {
        line(colLeft, 0, colLeft, imageHeight);
      }
      
      // rowTop, rowBottom, colLeft, colRight define the pixel
      // boundaries of the box corresponding to our ascii
      
      // Now we are ready to take the average value
      double lum = 0;
      int count = 0;
      
      for (int i = rowTop; i < rowBottom; i++) {
        for (int j = colLeft; j < colRight; j++) {
          color p = img.pixels[i*img.width+j];
          lum += blue(p) / 255.0;
          count++;
        }
      }
      
      lum = (1.0 - lum/count);
      
      // lum is between 0 and 1, and we can map it into ascii
      int paletteIndex = (int)Math.round(lum*(palette.length()-1));
      asciiRow.append(palette.charAt(paletteIndex));
    }
    asciiRow.append("\n");
    ascii.add(asciiRow.toString());
  }
  
  return ascii;
}

boolean isPrinting = false;

int lastPrintDone = 0;

void mousePressed() {
  if (! (mouseX >= width - buttonMargin - buttonWidth &&
         mouseX <= width - buttonMargin &&
         mouseY >= height - buttonMargin - buttonHeight &&
         mouseY <= height - buttonMargin)) {
    return;
  }

  if (isPrinting || millis() < lastPrintDone + 3000) {
    println("possible double print");
    return;
  }
  
  if (ascii != null && myPort != null) {
    isPrinting = true;
    println("typing portrait...");
    for (String s : ascii) {
      // make sure each row takes at least 15 seconds
      int m = millis();
      myPort.write(s);
      while (millis() < m + 12*1000);
    }
    lastPrintDone = millis();
    println("done");
    isPrinting = false;
  }
}

