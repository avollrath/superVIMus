# superVIMus

![superVIMus preview](./supervimus.webp)

superVIMus is a small browser-playable puzzle game built to help you build muscle memory for Vim's `hjkl` movement keys.

[Play it here](https://avollrath.github.io/superVIMus/)

## Overview

superVIMus takes a familiar editor habit and turns it into a game. Instead of memorizing `h`, `j`, `k`, and `l` through dry repetition, you practice them by moving through short grid-based puzzle spaces, pushing pigs into holes, dodging hazards, and building speed through play.

The result is a compact Godot project that mixes simple mechanics, playful pixel art, and just enough chaos to make the controls stick.

## Features

- Vim-style movement using `h`, `j`, `k`, and `l`
- Grid-based puzzle gameplay with box-pushing mechanics
- Pixel-art presentation with a playful, slightly absurd tone
- Browser-playable HTML5 export
- Built in Godot with GDScript

## Why This Project Exists

Learning Vim movement is mostly a muscle-memory problem. The keys are simple, but they only become natural after enough repetition. superVIMus was designed as a more fun way to get that repetition in by turning navigation practice into an actual play loop.

## Controls

- `h`: move left
- `j`: move down
- `k`: move up
- `l`: move right

## Tech Stack

- Engine: Godot
- Language: GDScript
- Platform: HTML5/Web export
- Structure: scene-based project with grid movement and puzzle systems


## Development

This repository contains the full Godot project used to build the web version. The main game starts from the scene defined in the project configuration and is exported to the `docs/` folder for GitHub Pages hosting.

## Credits

Created by Andre Vollrath.

If you use Vim, give it a try and see whether your fingers start reaching for `hjkl` a little faster afterward.
