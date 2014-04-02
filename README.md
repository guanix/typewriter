Typewriter ASCII art
====================

## Arduino

The brother3 Arduino sketch is currently set up for Brother GX-6750
typewriters. Operation is very simple: simply send ASCII over the serial
port, 8N1-115200. Sleep for up to 12 seconds to make sure the line is done
printing and we don't overrun buffers.

## Processing

Requires [opencv-processing](https://github.com/atduskgreg/opencv-processing).

ASCII conversion is very simple: each block of pixels corresponding to an
ASCII character is sampled. The average brightness is mapped linearly to a
palette of characters, currently 22 characters long stolen from
[jp2a](http://csl.name/jp2a/).
