#!/usr/bin/env python

import os
import codecs
from xml.dom import minidom
import subprocess
import sys

INKSCAPE = '/usr/bin/inkscape'

def list_layers(svg):
    layers = [ ]
    for g in svg.getElementsByTagName("g"):
        if g.attributes.has_key("inkscape:label"):
            layers.append(g.attributes["inkscape:label"].value)
    return layers

def export_layer(svg, directory, layer, stay):
    if layer in stay:
        return
    print layer, "..."
    for g in svg.getElementsByTagName("g"):
        if g.attributes.has_key("inkscape:label"):
            label = g.attributes["inkscape:label"].value
            if label == layer or label in stay:
                g.attributes['style'] = 'display:inline'
            else:
                g.attributes['style'] = 'display:none'
    dest = os.path.join(directory, layer + ".svg")
    codecs.open(dest, "w", encoding="utf8").write(svg.toxml())
    png = os.path.join(directory, layer + ".png")
    subprocess.check_call([INKSCAPE, "--export-png", png, dest])
    os.unlink(dest)

def main():
    from argparse import ArgumentParser
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--stay', action='append', default=[], help='layer to always have visible')
    parser.add_argument('src', help='source SVG file.')
    args = parser.parse_args()

    svg = minidom.parse(open(args.src))

    for layer in list_layers(svg):
        export_layer(svg, os.path.dirname(args.src), layer, args.stay)

if __name__ == '__main__':
    main()
