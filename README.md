nimrod-cairo-bindings
=====================

Cairo graphics bindings for Nimrod language

Started by running the 'c2nim' tool on the cairo.h header, then did some renaming
to better fit Nimrod's style.

Cairo types, which are of the form 'cairo_surface_t' are here 'Tsurface', 
and can be used as 'var surface: cairo.Tsurface = ...' for example.

This isn't well-tested yet.  The complete set of bindings is present, and the
ones I've tested work.  But that's as far as it goes, for the moment.  There is
a working example -- an analog clock drawn with cairo primitives, lifted from the
[cairosdl] project, and displayed on an SDL2 window.

To run the sample, you'll need to have installed libcairo and libSDL2.  

You may find, as I did, that the nimrod dynlib name in the bindings files
(for SDL2 and for cairo here), might need to be tweaked to match the actual
shared-library filenames on your system.  For me, on linux Mint 17, the
difficulty seemed to be that the loader wouldn't follow symlinks, so that
the 'libSDL2.so' had to be given as 'libSDL2-2.0.so.0' instead. 



Ref:
---
- Nimrod language[www.nimrod-lang.org]
- Cairo graphics[www.cairographics.org]