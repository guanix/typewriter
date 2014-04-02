#define NCOLS 8
#define NROWS 8
#define PERIODS 6

int8_t cols[NCOLS] = { 12, 11, 10, 9, 8, 7, 6, 5 };
int8_t rows[NROWS] = { 4, 3, 2, A5, A4, A3, A2, A1 };

void type(int8_t row, int8_t col, int8_t mod) {
  // hold the key for PERIODS periods
  
  // SHIFT: 5, 0
  // CODE: 6, 7
  
  int8_t row1_pin = rows[row];
  int8_t col1_pin = cols[col];
  int8_t row2_pin = -1;
  int8_t col2_pin = -1;
  
  if (mod == 1) {
    row2_pin = rows[5];
    col2_pin = cols[0];
    type(5, 0, -1);
  } else if (mod == 2) {
    row2_pin = rows[6];
    col2_pin = cols[7];
  }

  // We only assert the column for the last 100 us of the period
  for (uint8_t period = 0; period < PERIODS; period++) {
    // first code
    if (mod <= 0) { // one row
      while (digitalRead(row1_pin) == HIGH);
      pinMode(col1_pin, OUTPUT);
      delayMicroseconds(50);
      while (digitalRead(row1_pin) == LOW);
      delayMicroseconds(50);
      pinMode(col1_pin, INPUT);
    } else { // two rows
      while (digitalRead(row1_pin) == HIGH && digitalRead(row2_pin) == HIGH);
      if (digitalRead(row1_pin) == LOW) {
        pinMode(col1_pin, OUTPUT);
        delayMicroseconds(50);
        while (digitalRead(row1_pin) == LOW);
        delayMicroseconds(50);
        pinMode(col1_pin, INPUT);
      } else {
        pinMode(col2_pin, OUTPUT);
        delayMicroseconds(50);
        while (digitalRead(row2_pin) == LOW);
        delayMicroseconds(50);
        pinMode(col2_pin, INPUT);
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("hello");
  
  for (int i = 0; i < NCOLS; i++) {
    pinMode(cols[i], INPUT);
    digitalWrite(cols[i], LOW);
  }
  
  for (int i = 0; i < NROWS; i++) {
    pinMode(rows[i], INPUT_PULLUP);
  }
}

int previousRow = -1, previousCol = -1;
unsigned long previousPrint = 0;

void displayScan() {
  for (int i = 0; i < NROWS; i++) {
    if (digitalRead(rows[i]) == LOW) {
      delayMicroseconds(200);
      if (digitalRead(rows[i]) != LOW) {
        continue;
      }
      for (int j = 0; j < NCOLS; j++) {
        if (digitalRead(cols[j]) == LOW) {
          delayMicroseconds(200);
          if (digitalRead(cols[j]) != LOW) {
            continue;
          }
          if ((millis() - previousPrint > 1000) || (previousRow != i || previousCol != j)) {
            Serial.print("row=");
            Serial.print(i);
            Serial.print(" col=");
            Serial.println(j);
          
            previousRow = i;
            previousCol = j;
            previousPrint = millis();
          }
        }
      }
    }
  } 
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    
    int mod = 0;
    
    if (c >= 'A' && c <= 'Z') {
      c = c - ('A' - 'a');
      mod = 1;
    }
    
    switch (c) {
      case 'a':
        type(3, 1, mod);
        break;
      case 'b':
        type(4, 7, mod);
        break; 
      case 'c':
        type(0, 7, mod);
        break; 
      case 'd':
        type(3, 4, mod);
        break;
      case 'e':
        type(2, 2, mod);
        break;
      case 'f':
        type(0, 2, mod);
        break;
      case 'g':
        type(3, 2, mod);
        break;
      case 'h':
        type(0, 3, mod);
        break;
      case 'i':
        type(4, 5, mod);
        break;
      case 'j':
        type(3, 3, mod);
        break;
      case 'k':
        type(0, 5, mod);
        break;
      case 'l':
        type(3, 5, mod);
        break;
      case 'm':
        type(4, 6, mod);
        break;
      case 'n':
        type(2, 6, mod);
        break;
      case 'o':
        type(2, 4, mod);
        break;
      case 'p':
        type(4, 4, mod);
        break;
      case 'q':
        type(2, 1, mod);
        break;
      case 'r':
        type(4, 2, mod);
        break;
      case 's':
        type(0, 4, mod);
        break;
      case 't':
        type(2, 3, mod);
        break;
      case 'u':
        type(2, 5, mod);
        break;
      case '>':
        type(2, 5, 2);
        break;
      case 'v':
        type(2, 7, mod);
        break;
      case 'w':
        type(4, 1, mod);
        break;
      case '<':
        type(4, 1, 2);
        break;
      case 'x':
        type(0, 6, mod);
        break;
      case 'y':
        type(4, 3, mod);
        break;
      case 'z':
        type(0, 1, mod);
        break;
      case '\n':
        type(6, 1, 0);
        break;
      case ' ':
        type(6, 0, 0);
        break;
      case '0':
        type(1, 7, 0);
        break;
      case ')':
        type(1, 7, 1);
        break;
      case '1':
        type(7, 2, 0);
        break;
      case '!':
        type(7, 2, 1);
        break;
      case '2':
        type(1, 2, 0);
        break;
      case '@':
        type(1, 2, 1);
        break;
      case '3':
        type(7, 3, 0);
        break;
      case '#':
        type(7, 3, 1);
        break;
      case '4':
        type(1, 3, 0);
        break;
      case '$':
        type(1, 3, 1);
        break;
      case '5':
        type(7, 5, 0);
        break;
      case '%':
        type(7, 5, 1);
        break;
      case '6':
        type(1, 5, 0);
        break;
      case '7':
        type(7, 4, 0);
        break;
      case '&':
        type(7, 4, 1);
        break;
      case '8':
        type(1, 4, 0);
        break;
      case '*':
        type(1, 4, 1);
        break;
      case '9':
        type(7, 7, 0);
        break;
      case '(':
        type(7, 7, 1);
        break;
      case '-':
        type(7, 6, 0);
        break;
      case '_':
        type(7, 6, 1);
        break;
      case '=':
        type(1, 6, 0);
        break;
      case '+':
        type(1, 6, 1);
        break;
      case ';':
        type(0, 0, 0);
        break;
      case ':':
        type(0, 0, 1);
        break;
      case '\'':
        type(3, 0, 0);
        break;
      case '"':
        type(3, 0, 1);
        break;
      case ',':
        type(7, 0, 0);
        break;
      case '.':
        type(1, 0, 0);
        break;
      case '/':
        type(7, 1, 0);
        break;
      case '?':
        type(7, 1, 1);
        break;
      case ']':
        type(4, 0, 0);
        break;
      case '[':
        type(4, 0, 1);
        break;
      default:
        type(7, 1, 1);
        break;
    }
    delay(50);
  } else {
    displayScan();
  }
}

