BUILD: OTTER & MOSEY — THE LOST ISLANDS

A Premium Native iOS Educational Adventure Game

You are an expert iOS game developer, Swift engineer, SpriteKit specialist, game designer, children’s educational specialist, animator, sound designer and creative director.

Your task is to DESIGN AND IMPLEMENT a beautiful, fully playable native iOS adventure game called:

OTTER & MOSEY: THE LOST ISLANDS

The game is designed for UK Year 3 children aged 8–9.

It combines:

* Spelling
* Typing
* Mathematics
* Adventure
* Exploration
* Collectables
* Character progression
* Storytelling
* Humour

The game must feel like a premium Nintendo-quality children’s adventure rather than a conventional educational app.

IMPORTANT: This is a NATIVE iOS project, not a web application.

Do not use React Native, Flutter, Unity, Phaser, WebViews or HTML5.

Use Swift, SpriteKit, SwiftUI and Apple’s native frameworks.

Implement the game directly in the existing repository, or initialise a new Xcode project if necessary.

Do not stop at a design document or prototype.

Build a genuinely playable application.

⸻

1. PLATFORM REQUIREMENTS

Target platforms

* iPhone
* iPad
* iOS 26 and later
* iPadOS 26 and later

Orientation

LANDSCAPE ONLY.

Support:

* Landscape Left
* Landscape Right

Do not support portrait gameplay.

Ensure the app’s orientation settings are configured correctly in the Xcode project.

Display adaptation

The game must look exceptional on:

* iPhone 16 Pro Max
* Smaller modern iPhones
* iPad mini
* Standard iPad
* iPad Air
* iPad Pro

Do not simply stretch the same layout across devices.

Use responsive game layouts that adapt to:

* Screen size
* Aspect ratio
* Safe areas
* Display scale
* Available input methods

On iPhone:

* Larger touch targets
* Compact HUD
* Shorter text
* Simplified typing interactions
* More focused camera framing

On iPad:

* More expansive environments
* Additional environmental detail
* Richer layouts
* More visible gameplay area
* Full typing challenges
* Better use of screen space

All important controls must remain accessible around the Dynamic Island, camera cutout, rounded corners and safe areas.

⸻

2. TECHNOLOGY STACK

Use:

* Swift 6
* SwiftUI
* SpriteKit
* GameplayKit where useful
* AVFoundation
* Core Haptics
* SwiftData or Codable-based local persistence
* XCTest / Swift Testing

Architecture

Use SwiftUI for:

* App lifecycle
* Main menu
* Settings
* Player profiles
* Parent dashboard
* Accessibility settings
* Native overlays where appropriate

Use SpriteKit for:

* Interactive game worlds
* Character movement
* Animation
* Particle effects
* Collisions
* Environmental interactions
* Minigames
* Guardian encounters
* Camera movement

Use SKScene and SKCameraNode for gameplay scenes.

Keep gameplay logic separate from presentation.

Avoid unnecessarily complex architecture.

Suggested project structure:

OtterAndMosey/
App/
Game/
Scenes/
Characters/
Mechanics/
Systems/
Effects/
Camera/
Education/
Spelling/
Maths/
Typing/
Difficulty/
QuestionBank/
UI/
Components/
Menus/
HUD/
ParentDashboard/
Audio/
Assets/
Characters/
Environments/
Props/
Effects/
Audio/
Persistence/
Models/
Tests/

Use protocols and reusable components where they improve maintainability.

⸻

3. THE STORY

Otter and Mosey are best friends living on a beautiful magical tropical island.

Otter is a mischievous brown otter.

Mosey is a friendly blue mosasaur.

One morning, the Great Rainbow Crystal mysteriously shatters.

Its six magical fragments scatter across the surrounding islands.

As the crystal fragments disappear, the islands begin losing their colours.

Trees turn grey.

Flowers stop blooming.

Waterfalls stop flowing.

Magical creatures become confused and unhappy.

Otter and Mosey decide to recover the six fragments and restore their world.

The adventure takes them through six magical islands.

Each island contains:

* A distinctive environment
* Interactive exploration
* Educational challenges
* Collectable objects
* Funny characters
* Hidden secrets
* A guardian encounter
* A crystal fragment

The story should be funny, charming and emotionally engaging.

Keep dialogue short.

Use animated speech bubbles and expressive character reactions.

Allow players to skip dialogue.

⸻

4. MAIN CHARACTERS

OTTER

A lovable brown otter.

Appearance:

* Warm chocolate-brown fur
* Cream muzzle and belly
* Rounded ears
* Large expressive eyes
* Cute whiskers
* Long tail
* Teal adventurer’s scarf

Personality:

* Adventurous
* Mischievous
* Energetic
* Curious
* Occasionally clumsy
* Loves words and spelling

Otter should be animated and highly expressive.

MOSEY

A beautiful bright-blue female mosasaur.

Appearance:

* Ocean-blue body
* Turquoise belly
* Rounded friendly snout
* Large expressive eyes
* Four swimming flippers
* Long aquatic tail
* Small golden star accessory

IMPORTANT:

Mosey is a mosasaur, not a land dinosaur.

She must have anatomically recognisable flippers and an aquatic body shape.

Her design should be cute, approachable and expressive.

Personality:

* Intelligent
* Friendly
* Calm
* Playful
* Occasionally cheeky
* Loves mathematics
* Protective of Otter

FRIENDSHIP

Their friendship is the emotional heart of the game.

Include:

* Funny dialogue
* Playful teasing
* Shared celebrations
* Cooperative actions
* Character-specific reactions
* Friendship Power special moves

Both characters should remain visible throughout much of the adventure.

Allow the player to choose their favourite character.

⸻

5. WORLD DESIGN

Create six magical islands.

ISLAND 1: WHISPERING WOODS

Visual theme:

* Enchanted forests
* Giant mushrooms
* Talking trees
* Fireflies
* Magical streams
* Woodland creatures

Educational focus:

* Spelling
* Word completion
* Basic typing

Gameplay:

* Pop word bubbles
* Complete missing letters
* Build magical bridges
* Rescue woodland creatures
* Unlock forest pathways

Guardian:

A grumpy but lovable talking tree.

ISLAND 2: BUBBLE BAY

Visual theme:

* Underwater reefs
* Glowing jellyfish
* Sunken treasure
* Colourful fish
* Ancient shipwrecks
* Magical underwater caves

Educational focus:

* Addition
* Subtraction

Gameplay:

* Swim through answer tunnels
* Open treasure chests
* Rescue sea creatures
* Collect magical pearls
* Navigate underwater puzzles

Guardian:

A gigantic, confused octopus.

ISLAND 3: DRAGONFIRE MOUNTAIN

Visual theme:

* Volcanoes
* Lava rivers
* Friendly dragons
* Crystal caves

Educational focus:

* Multiplication
* Times tables

Gameplay:

* Rescue baby dragons
* Crack magical eggs
* Cross number platforms
* Activate ancient machines

Guardian:

A silly dragon who accidentally sets his trousers on fire.

ISLAND 4: CLOUD CASTLE

Visual theme:

* Floating islands
* Rainbow bridges
* Cloud platforms
* Magical castles

Educational focus:

* Typing
* Sentence construction
* Accuracy

Gameplay:

* Build cloud platforms
* Complete typing races
* Activate magical portals
* Repair flying machines

Guardian:

A mischievous cloud wizard.

ISLAND 5: CANDY KINGDOM

Visual theme:

* Chocolate rivers
* Candy forests
* Biscuit castles
* Sweet factories

Educational focus:

* Division
* Fractions
* Word problems

Gameplay:

* Divide sweets
* Repair candy machines
* Solve fraction puzzles
* Navigate conveyor belts

Guardian:

A giant marshmallow monster.

ISLAND 6: STARLIGHT ISLAND

Visual theme:

* Stars
* Glowing planets
* Magical portals
* Floating crystals

Educational focus:

* Mixed spelling
* Typing
* Mathematics

Gameplay:

* Restore constellations
* Solve magical puzzles
* Navigate cosmic environments
* Recover the final crystal fragment

Final guardian:

A lonely shadow creature who ultimately becomes a friend.

⸻

6. CORE GAMEPLAY

The game must contain several genuinely distinct gameplay mechanics.

Do not implement the entire game as multiple-choice questions with different backgrounds.

GAME MODE A: WORD BLASTER

Floating magical bubbles appear.

Each bubble contains a word or missing letters.

The child must type the correct answer.

Correct answers pop the bubbles.

Implement:

* Animated bubbles
* Particle explosions
* Combo multipliers
* Character celebrations
* Increasing difficulty
* Helpful hints

On iPhone:

Use a custom, compact, touch-friendly keyboard for short words and missing letters.

On iPad:

Support longer words and sentences using an appropriately sized keyboard interface.

For physical keyboards:

Support direct hardware keyboard input.

GAME MODE B: MOSEY’S MATHS SPLASH

Mosey swims through an underwater obstacle course.

A maths question appears.

Three answer tunnels are presented.

The player selects the correct answer.

Correct answers create a colourful speed boost.

Implement:

* Smooth swimming animations
* Touch controls
* Animated water
* Collectable pearls
* Speed boosts
* Multiple difficulty levels

GAME MODE C: RAINBOW BRIDGE BUILDER

Otter and Mosey must cross a canyon.

Each correct answer creates a new rainbow bridge segment.

The bridge grows visibly.

The final answer completes the bridge.

Include spectacular completion effects.

GAME MODE D: DRAGON EGG RESCUE

Players solve multiplication challenges to rescue baby dragons.

Correct answers crack eggs.

Baby dragons emerge and celebrate.

Each rescued dragon becomes a collectable companion.

GAME MODE E: TYPING TURBO

A side-scrolling typing race.

Otter and Mosey travel through a colourful environment.

Typing accurately makes their vehicle accelerate.

Implement:

* Animated scenery
* Progress meter
* Combo bonuses
* Speed effects
* Finish-line celebration

Adapt difficulty to input method.

Do not make typing speed mandatory for progression.

GAME MODE F: CRYSTAL GUARDIAN ENCOUNTERS

Each island ends with a guardian.

Correct answers charge the Friendship Power meter.

Once charged, Otter and Mosey perform a spectacular cooperative special move.

Guardians must be funny rather than frightening.

Include:

* Multiple phases
* Guardian reactions
* Animated attacks using harmless magical effects
* Friendship Power
* Victory celebrations

⸻

7. TOUCH-FIRST GAME DESIGN

This is critically important.

The game is primarily intended for children using iPhones and iPads.

Do not design a desktop game and simply add touch support.

Implement intuitive touch interactions.

Examples:

* Tap to select
* Drag to move objects
* Swipe to swim
* Tap bubbles
* Drag letters into position
* Tap number platforms
* Swipe between islands

Use large, forgiving touch targets.

Avoid tiny controls.

Avoid requiring complex multitouch gestures.

MOVEMENT

Where movement is required, use simple touch controls.

Options include:

* Virtual joystick
* Tap-to-move
* Contextual movement buttons
* Swipe-based navigation

Choose the most appropriate control scheme for each minigame.

Do not require a permanent virtual joystick for gameplay that does not benefit from one.

KEYBOARD INPUT

Support three input modes:

1. Custom game-themed touch keyboard
2. Native iOS keyboard where appropriate
3. External hardware keyboard

The keyboard should not obscure the educational question or active gameplay.

For iPhone landscape, prefer compact letter-entry interfaces.

For iPad, allow more extensive typing.

For hardware keyboards, provide proper typing accuracy and speed measurement.

Do not assume an external keyboard is connected.

⸻

8. EDUCATIONAL CONTENT

Align content broadly with England’s Year 3 curriculum.

Use UK English spelling.

SPELLING

Include:

* Year 3 common exception words
* Prefixes
* Suffixes
* Homophones
* Missing letters
* Complete words
* Sentence construction

Create a substantial curated word bank.

Validate the spelling of every answer.

MATHEMATICS

Include:

* Addition
* Subtraction
* Multiplication
* Division
* 3, 4 and 8 times tables
* Reinforcement of 2, 5 and 10 times tables
* Fractions
* Place value
* Number sequences
* Simple word problems

Generate mathematically correct questions.

Avoid ambiguous answers.

ADAPTIVE DIFFICULTY

Track:

* Accuracy
* Response times
* Repeated mistakes
* Topic proficiency
* Typing accuracy
* Typing speed

Adjust challenge difficulty automatically.

Use spaced repetition for troublesome words and maths topics.

Always provide encouragement.

Never shame children for mistakes.

⸻

9. AI IMAGE GENERATION

You have access to OpenAI image generation.

The API key is available through:

OPENAI_API_KEY_CHATGPT_GRAPHICS

If missing, execute:

bw-reload

Then check again.

Use the OpenAI Images API.

Prefer ChatGPT Images 2.5 if available through the API.

Verify the correct model identifier and supported API parameters before use.

Do not invent API model names.

Generate actual production-quality game assets.

REQUIRED ARTWORK

Generate:

* Otter character reference
* Mosey character reference
* Character expression sheets
* Character animation spritesheets
* Title-screen artwork
* Island environments
* Parallax backgrounds
* Interactive props
* Guardians
* Collectables
* Rainbow Crystal fragments
* UI decorations
* Character accessories
* Achievement icons

CHARACTER CONSISTENCY

Create definitive character reference artwork first.

Use it as the visual reference for subsequent assets.

Maintain consistent:

* Colours
* Proportions
* Facial features
* Accessories
* Art style

SPRITE GENERATION

Where possible:

* Generate transparent backgrounds
* Use consistent sprite dimensions
* Separate individual animation frames
* Ensure animation registration points align
* Package assets into Xcode asset catalogues

Use programmatic SpriteKit animation.

Do not rely on static character illustrations for all gameplay.

BACKGROUNDS

Generate richly detailed, layered environments.

Use parallax scrolling.

Separate foreground, midground and background where practical.

Create environments that feel alive.

ASSET OPTIMISATION

Optimise images for iOS.

Avoid unnecessarily large textures.

Use texture atlases where beneficial.

Ensure the app does not need an internet connection to load its artwork.

⸻

10. SOUND DESIGN

SFXMint has been installed using:

npx skills add sfxmint/sfxmint-mcp -y

Inspect the installed skill.

Discover the available sound-generation tools.

Generate original sound effects for:

* Button taps
* Menu navigation
* Correct answers
* Incorrect answers
* Bubble popping
* Crystal collection
* Star collection
* Jumping
* Swimming
* Dragon eggs cracking
* Baby dragon chirping
* Magical portals
* Guardian reactions
* Friendship Power
* Level completion
* Island unlocking
* Victory celebrations

Use AVFoundation and appropriate native audio APIs.

Provide:

* Music volume
* Effects volume
* Mute
* Respect for silent-mode behaviour
* Audio interruption handling

Add subtle haptic feedback where supported.

Do not make haptics essential to gameplay.

Ensure audio is pleasant and never excessively loud.

⸻

11. VISUAL QUALITY

The game must look spectacular.

Aim for:

* Premium cartoon artwork
* Beautiful 2.5D environments
* Smooth character animation
* Rich environmental detail
* Soft lighting
* Vibrant colours
* Atmospheric particles
* Animated water
* Parallax backgrounds
* Dynamic camera movement
* Magical effects
* Delightful transitions

Use SpriteKit features such as:

* SKEmitterNode
* SKAction
* SKCameraNode
* SKTextureAtlas
* SKShader where useful

Avoid excessive shaders that cause poor performance.

Target smooth 60 FPS gameplay on supported devices.

Create delightful microinteractions.

Examples:

* Otter blinks and scratches his head while waiting.
* Mosey playfully splashes water.
* Characters exchange glances.
* Flowers bloom after correct answers.
* Crystals sparkle.
* Fireflies drift through forests.
* Bubbles wobble before popping.
* The world gradually regains colour.

WORLD RESTORATION

This is a signature mechanic.

The environment should visibly transform as the player completes challenges.

At the beginning of an island:

* Muted colours
* Fewer environmental animations
* Dull lighting
* Dormant plants

As the player progresses:

* Colours return
* Flowers bloom
* Water begins flowing
* Creatures reappear
* Magical particles become more vibrant

On completing an island:

Trigger a spectacular world-restoration sequence.

This should feel like a major achievement.

⸻

12. MAIN MENU AND WORLD MAP

TITLE SCREEN

Create a beautiful animated title screen.

Show Otter and Mosey together.

Include:

* Game logo
* Play
* Continue
* Settings
* Player selection

The background should be animated.

Characters should react to user interaction.

WORLD MAP

Create a beautiful interactive archipelago map.

Show all six islands.

Each island should have a distinctive miniature appearance.

Support:

* Tap to select
* Animated island previews
* Locked/unlocked states
* Progress indicators
* Crystal collection status
* Smooth transitions

Completed islands should visibly regain colour.

⸻

13. PROGRESSION

Implement:

* Multiple levels per island
* Three-star ratings
* Collectable crystals
* Unlockable outfits
* Character accessories
* Collectable pets
* Achievements
* Home island decoration
* Friendship Power

No advertisements.

No microtransactions.

No loot boxes.

No mandatory online accounts.

MULTIPLE PLAYER PROFILES

Allow multiple children to maintain separate progress.

Use local profiles.

Support:

* Nickname
* Avatar
* Individual save progress
* Individual educational difficulty
* Individual achievements

Do not collect unnecessary personal information.

⸻

14. PARENT DASHBOARD

Build a SwiftUI parent dashboard.

Include:

* Total playtime
* Spelling accuracy
* Maths accuracy
* Typing accuracy
* Typing speed
* Skills practised
* Areas needing improvement
* Recent achievements

Allow configuration of:

* Difficulty
* Times tables
* Spelling topics
* Session duration
* Timed challenges
* Sound
* Accessibility

Keep this interface separate from children’s gameplay.

Use an appropriate parental gate for access to parent-only settings.

⸻

15. ACCESSIBILITY

Include:

* Reduced-motion support
* Adjustable audio
* Readable typography
* High-contrast options
* Optional dyslexia-friendly typography
* No mandatory timers
* Forgiving touch controls
* Helpful hints
* Clear feedback
* Optional audio instructions

Support children who struggle with reading or typing.

Avoid unnecessarily complex navigation.

Make all important gameplay instructions understandable.

⸻

16. OFFLINE-FIRST DESIGN

The game should function without an internet connection.

Bundle:

* Educational question banks
* Character artwork
* Environment artwork
* Sound effects
* Level definitions

Store progress locally.

Do not require a backend.

Do not require authentication.

Do not require an OpenAI API key at runtime.

AI generation is used during DEVELOPMENT to create assets, not during children’s gameplay.

Never embed the OpenAI API key in the application bundle.

⸻

17. GAME STATE AND SAVING

Implement robust persistence.

Save:

* Player profiles
* Current island
* Unlocked levels
* Stars
* Collected items
* Character customisation
* Educational performance
* Achievements
* Settings

Use a versioned save-data structure.

Handle interrupted sessions gracefully.

Avoid losing progress if the application is terminated.

⸻

18. FIRST-RUN EXPERIENCE

The game begins with Otter and Mosey enjoying their beautiful island.

They exchange a funny conversation.

Suddenly, a magical explosion occurs.

The Rainbow Crystal shatters.

The world begins losing colour.

Otter and Mosey decide to investigate.

The player learns the controls through a short interactive tutorial.

The first challenge should be extremely easy.

Completing it restores colour to a small part of the environment.

Flowers bloom.

Butterflies appear.

The characters celebrate.

The player immediately understands:

“My answers bring the world back to life!”

Keep the introduction short and engaging.

Allow skipping.

⸻

19. IMPLEMENTATION PLAN

Implement in stages, but do not stop after planning.

STAGE 1 — PROJECT FOUNDATION

* Create native Xcode project
* Configure iOS/iPadOS targets
* Configure landscape orientations
* Implement SwiftUI app shell
* Implement SpriteKit integration
* Implement navigation
* Implement save system

STAGE 2 — ARTWORK

* Generate Otter
* Generate Mosey
* Establish character consistency
* Generate first island assets
* Generate title-screen artwork
* Generate UI assets
* Import assets into Xcode

STAGE 3 — ANIMATION

* Character idle animations
* Character movement
* Character celebrations
* Environmental animation
* Particle effects
* Camera movement

STAGE 4 — EDUCATIONAL ENGINE

* Question banks
* Maths generators
* Spelling validation
* Adaptive difficulty
* Performance tracking
* Spaced repetition

STAGE 5 — PLAYABLE GAMEPLAY

Implement at least:

* Word Blaster
* Maths Splash
* Rainbow Bridge Builder
* Typing Turbo

All four must be genuinely playable.

STAGE 6 — STORY AND PROGRESSION

* Introductory cinematic
* World map
* Whispering Woods
* Bubble Bay
* Level unlocking
* Crystal collection
* Guardian encounters

STAGE 7 — AUDIO

* Generate sound effects
* Implement audio manager
* Add music
* Add haptics
* Add volume settings

STAGE 8 — POLISH

* Improve visual effects
* Improve transitions
* Improve character animation
* Optimise performance
* Test different screen sizes
* Fix bugs

⸻

20. MINIMUM PLAYABLE DELIVERABLE

Do not attempt to implement six mediocre islands at the expense of quality.

Prioritise a polished, genuinely playable vertical slice.

The minimum deliverable must include:

1. A working native iOS application.
2. Landscape support on iPhone and iPad.
3. Beautiful animated title screen.
4. Consistent Otter and Mosey artwork.
5. Animated characters.
6. Introductory story sequence.
7. Interactive world map.
8. Whispering Woods with multiple levels.
9. Bubble Bay with multiple levels.
10. At least four distinct educational gameplay modes.
11. Functional spelling questions.
12. Functional maths questions.
13. Adaptive difficulty.
14. Sound effects.
15. Particle effects.
16. Working save/load.
17. Stars and progression.
18. Parent settings.
19. A complete playable path through the first island.

Implement the remaining islands as subsequent expansion milestones if necessary.

Never present an unfinished feature as complete.

⸻

21. TESTING AND VALIDATION

Use Xcode build tools.

Build for the iOS Simulator.

Test both iPhone and iPad configurations.

If simulators are available, launch the app and inspect actual gameplay.

Test:

* Landscape orientation
* Safe-area layout
* Touch interactions
* Keyboard input
* Scene transitions
* Educational question correctness
* Audio controls
* Save/load
* Performance
* Asset loading
* App lifecycle interruptions

Create automated tests for educational logic and persistence.

Resolve build errors before declaring completion.

Do not claim simulator testing unless it was actually performed.

⸻

22. DEVELOPMENT ENVIRONMENT

Assume development is taking place on macOS.

Use Xcode and the available command-line tools.

Prefer:

* xcodebuild
* xcrun
* simctl
* Swift Package Manager

Use the installed OpenAI image-generation capability.

Use the installed SFXMint capability.

Do not commit secrets.

Do not embed API keys in source code.

Document all required development dependencies.

⸻

23. FINAL DELIVERABLES

Produce:

* Complete Xcode project
* Swift source code
* Generated artwork
* Sprite atlases
* Sound effects
* Educational question banks
* Local persistence
* Automated tests
* README
* Build instructions

Provide a concise implementation summary describing:

* What was built
* What is playable
* Which assets were generated
* Which tests were run
* Any remaining limitations
* How to launch the app

Do not substitute a written plan for implementation.

⸻

24. FINAL CREATIVE DIRECTION

This should be a game children genuinely LOVE.

It must feel:

* Magical
* Funny
* Adventurous
* Colourful
* Rewarding
* Responsive
* Charming
* Beautifully animated

The educational content should feel like part of the adventure.

Children should become attached to Otter and Mosey.

The world should reward curiosity.

Correct answers should have satisfying consequences.

Mistakes should be opportunities to learn.

The game should inspire children to return because they want to discover what happens next.

The ambition is to create a premium-quality iOS children’s adventure game that just happens to teach spelling, typing and mathematics.

Begin implementing the native iOS application now.

Do not stop after planning.

Build, generate assets, compile, test and iterate.

Budget for OPENAI key is approx. $20 - do not go over budget.

I would like to potentially expand this game to web and Android at some point, so please take that into account.