import processing.video.*;
import java.util.Arrays;
import processing.serial.*;
import gab.opencv.*;
import java.awt.Rectangle;
import org.opencv.imgproc.Imgproc;
import org.opencv.core.Mat;
import org.opencv.core.Core;
import org.opencv.core.Scalar;
import org.opencv.core.Point;

// This will probably be something like /dev/ttyUSB0 on Linux
// and COM17 on Windows. We could add a user interface for this
// but we are lazy.
final String serialDev = "/dev/cu.usbserial-AH00ZNA4";
final String cameraDev = "/dev/video0";
final String sliderDev = "/dev/cu.usbmodem12341";

// Rotation, in degrees
final int rotationDegrees = 0;

// Adjustment range
final float thresholdMin = 0;
final float thresholdMax = 255;
final float contrastMin = 0;
final float contrastMax = 5;

float thresholdCurrent = 100;
float contrastCurrent = 3;

// Width and height in ASCII characters
// Aspect ratio may not necessarily match pixels because
// the typewriter's font is not square
final int asciiWidth = 60;
final int asciiHeight = 30;

// Width and height of the image in pixels
final int imageWidth = 640;
final int imageHeight = 480;

// Turn some features on and off
final boolean detectFaces = false,
              drawBlocks = false;

Serial myPort, sliderPort;
OpenCV opencv, maskcv;
Capture cam;
PFont f;
StringBuffer serialBuffer;
Integer previousControl = -1;

boolean printNow = false;

// This is in greyscale order, 23 characters
// So a box whose average 1-luma is > 22/23 will be M.
final String palette = "   ...',;:clodxkO0KXNWM";

// Character size we are printing on screen
final int textHeight = 14;

// Array representing the rendered ASCII image
ArrayList<String> ascii;

void setup() {
  // Window size
  size(imageWidth*2, imageHeight, P2D);
  
  // Create font
  f = createFont("Courier", textHeight, true);
  textFont(f);
  
  // Set up webcam
  String[] cameras = Capture.list();
  for (String camera : cameras) {
    println(camera);
  }
//  cam = new Capture(this, imageWidth, imageHeight, cameraDev, 30);
  cam = new Capture(this, imageWidth, imageHeight, 30);
  cam.start();
  frameRate(10);
  
  // Set up OpenCV
  opencv = new OpenCV(this, imageWidth, imageHeight);
  
  // Set up rotation matrix
  Point center = new Point(imageWidth/2, imageHeight/2);
  rotationMatrix = Imgproc.getRotationMatrix2D(center, rotationDegrees, 1.0);
  
  if (detectFaces) {
    opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  }
  
  // Set up serial port. We will operate fine without one.
  try {  
    myPort = new Serial(this, serialDev, 115200);
    println("serial port opened");
  } catch (RuntimeException e) {
    println("serial port not present: " + e.toString());
  }
  
  // Try to set up the slider device serial port
  try {
    sliderPort = new Serial(this, sliderDev, 115200);
    println("slider serial port opened");
    serialBuffer = new StringBuffer();
  } catch (RuntimeException e) {
    println("slider serial port not present: " + e.toString());
  }
}

int counter = 0;
int frameNumber = 0;
Rectangle[] faces;
Mat rotationMatrix;

void draw() {
  if (cam.available()) {
    frameNumber++;

    background(255);
    
    cam.read();
    opencv.loadImage(cam);
    
    // Convert to luma
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_RGB2Lab);
    opencv.setGray(opencv.getR());
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_Lab2RGB);
    Imgproc.cvtColor(opencv.getColor(), opencv.getColor(), Imgproc.COLOR_RGB2BGRA);
    
    // Threshold mask, based on mouse cursor position
    Mat mask = opencv.getGray().clone();
    
    // Read settings from slider or cursor?
    if (sliderPort == null) {
      thresholdCurrent = map(mouseX, 0, width, thresholdMin, thresholdMax);
      contrastCurrent = map(mouseY, 0, height, contrastMin, contrastMax);
    }
    
    // Pre-contrast for threshold only
    Core.multiply(mask, new Scalar(0.6), mask);
    Imgproc.threshold(mask, mask, (int)Math.round(thresholdCurrent), 255, Imgproc.THRESH_BINARY);

    // Contrast for the original image    
    opencv.contrast(contrastCurrent);
    Mat original = opencv.getGray().clone();
    Core.bitwise_and(mask, original, original);
    
    // Unmirror
    Core.flip(original, original, OpenCV.VERTICAL);  
    
    // Rotation (necessary on Linux)
    if (rotationDegrees != 0) {
      Imgproc.warpAffine(original, original, rotationMatrix, original.size());
    }
    
    // Store our matrix back into the opencv object
    opencv.setGray(original);

    // Extract image data from opencv object and display
    PImage img = opencv.getOutput();
    image(img, 0, 0);
    
    if (detectFaces && frameNumber % 5 == 0) {
      // Do face detection
      faces = opencv.detect();
    }
    
    if (detectFaces && faces != null) {
      noFill();
      stroke(0, 255, 0);
      strokeWeight(3);
      for (int i = 0; i < faces.length; i++) {
        rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
      }
    }
    
    // Print the ASCII version on the right
    stroke(0);
    fill(0);
    textAlign(LEFT, TOP);
    ArrayList<String> ascii = toAscii(img);

    int textY = 0;
    for (String row : ascii) {
      textY += textHeight;
      text(row, imageWidth + 10, textY);
    }

    // Print some instructions
    fill(0, 0, 255);
    text("move cursor vertically for contrast, horizontally for threshold", imageWidth+10, imageHeight-40);
    fill(255, 0, 0);
    text("TOP OF PAPER MUST ALIGN WITH TOP OF CLEAR LID (we will reverse)", imageWidth+10, imageHeight-20);
  }
  
  // Print triggered from control panel?
  if (printNow) {
    println("print triggered from control panel");
    printNow = false;
    doPrint();
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

void keyPressed() {
  if (key != 'p') {
    return;
  }

  doPrint();
}
 
void doPrint() { 
  if (isPrinting || millis() < lastPrintDone + 3000) {
    println("possible double print");
    return;
  }
  
  println("printing...");
  
  if (ascii != null && myPort != null) {
    isPrinting = true;
    println("reversing 17 times to align correctly");
    for (int i = 0; i < 17; i++) {
      // should take 750 ms
      int m = millis();
      myPort.write(14);
      while (millis() < m + 750);
    }
    println("typing portrait...");

    lastPrintDone = millis();
    printAscii();
    println("done");

    // sign the image
    int n = millis();
    myPort.write("Don't litter!                                   FACETRON6000\n");
    while (millis() < n + 5000);
    
    println("forward 11 times to align correctly");
    for (int i = 0; i < 11; i++) {
      // should take 750 ms
      int m = millis();
      myPort.write("\n");
      while (millis() < m + 750);
    }

    isPrinting = false;
  }
}

void printAscii() {
  for (String s : ascii) {    
    // If all blank, just hit return
    boolean blank = true;
    for (int i = 0; i < s.length() - 1; i++) {
      if (s.charAt(i) != ' ') {
        blank = false;
      }
    }
    
    // See if there are spaces at the end
    int endSpaces = 0;
    for (int i = s.length() - 1; i >= 0; i--) {
      char c = s.charAt(i);
      if (c == '\n') { continue; }
      if (s.charAt(i) != ' ') {
        break;
      } else {
        endSpaces++;
      }
    }
    
    int m = millis();

    if (!blank) {
      // make sure each row takes at least 15 seconds
      myPort.write(s.substring(0, s.length() - endSpaces));

      // We stripped off the newline when we removed the trailing spaces
      if (endSpaces > 0) {
        myPort.write('\n');
      }
      
      // Pause for the carriage
      while (millis() < m + 12*1000 - endSpaces*120);
    } else {
      // make sure each newline takes at least 1 second
      myPort.write("\n");
      while (millis() < m + 1000);
    }
    
  }
}

void serialEvent(Serial p) {
  if (p == sliderPort) {
    serialBuffer.append(p.readString());
    if (serialBuffer.length() == 0) {
      return;
    }
    
    try {
      String[] m = match(serialBuffer.toString(), ".*a(\\d+),(\\d+),(\\d+)b");
      if (m != null && m.length == 4) {
        thresholdCurrent = map(Integer.parseInt(m[1]), 0, 1023, thresholdMin, thresholdMax);
        contrastCurrent = map(Integer.parseInt(m[2]), 0, 1023, contrastMin, contrastMax);
//        println("reading " + m[1] + " " + m[2] + " " + m[3]);
        
        Integer control = Integer.parseInt(m[3]);
        if (!isPrinting && previousControl == 0 && control == 1) {
          println("control panel triggering print");
          printNow = true;
        }
        
        previousControl = control;
          
        serialBuffer = new StringBuffer();
      }
    } catch (Exception e) {
      println(e.toString());
    }
  }
}

