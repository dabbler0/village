readline = require 'readline'

# An Action's @apply function accepts an ActionContext and mutates it, then executes a callback.
class Action
  constructor: (@text, @apply) ->

# An ActionContext
class ActionContext
  constructor: (@board, @textCard, @actingCard) ->
    @interact = @board.interact

  subcontext: (text, acting) -> new ActionContext @board, text, acting

class ProfessionTemplate
  constructor: (@name, @action) ->

  create: -> new Profession @name, @action

class Profession
  constructor: (@name, @action) ->

  render: -> "(P) #{@name}: #{@action.text}"

class Requirement
  constructor: (@text, @fn) ->

class Villager
  constructor: (@profession) ->
    @age = 0
    @acted = true

  render: -> "(V) #{@profession.name} [#{@age}] [#{if @acted then '#' else ' '}]: #{@profession.action.text}"

# A Building
class BuildingTypeTemplate
  constructor: (@name, @bulk, @hooks, @action, @storage = {food: 0, gold: 0, wood: 0}) ->

  create: -> new BuildingType @name, @bulk, @hooks, @action, @storage

class BuildingType
  constructor: (@name, @bulk, @hooks, @action, @storage) ->

  render: -> "(T) #{@name}: #{@action.text}"

formatFWG = (food, wood, gold) ->
  if food > 0 or wood > 0 or gold > 0 then " (#{[
    (if food > 0 then "#{food}F" else ""),
    (if wood > 0 then "#{wood}W" else ""),
    (if gold > 0 then "#{gold}G" else "")
  ].filter((x) -> x.length > 0).join(' ')})" else ""
class Building
  constructor: (@type, @progress = 0) ->
    @acted = false

    @food = 0
    @wood = 0
    @gold = 0

  render: -> "(B) #{@type.name}#{formatFWG(@food, @wood, @gold)} [#{@progress}/#{@type.bulk}][#{if @acted then '#' else ' '}]: #{@type.action.text}"

# A Technology
class TechnologyTemplate
  constructor: (@name, @requirement, @hooks, @action) ->

  create: -> new Technology(@name, @requirement, @hooks, @action)

class Technology
  constructor: (@name, @requirement, @hooks, @action) ->
    @food = 0
    @wood = 0
    @gold = 0

  render: -> "(R) #{@name}#{formatFWG(@food, @wood, @gold)}\n  Requires: #{@requirement.text}#{if @action? then "\n  Action: #{@action.text}" else ""}#{("\n  #{key}: #{val.text}" for key, val of @hooks).join('')}"

# The Board consists of four VISIBLE card areas (Tableau) and three INVISIBLE ones (Decks).
#
# VILLAGERS
# TECHNOLOGIES
# BUILDINGS
# REVEALED CARD AREA
#
# VILLAGER DECK & DISCARD
# TECHNOLOGIES DECK & DISCARD
# BUILDINGS DECK & DISCARD

class Tableau
  constructor: (@cards = []) ->

  place: (cards) ->
    unless cards.length? then cards = [cards]

    for card in cards
      @cards.push card

  remove: (card) ->
    @cards = @cards.filter (x) -> x isnt card

  wipe: ->
    cards = @cards
    @cards = []
    return cards

class Deck
  constructor: (@cards = []) ->
    @discard = new Tableau()

  shuffle: ->
    @cards.sort (a, b) -> if Math.random() > 0.5 then 1 else -1

  reshuffle: ->
    @cards = @cards.concat @discard.wipe()
    @shuffle()

  draw: ->
    if @cards.length >= 1
      return @cards.pop()
    else
      @reshuffle()
      return @cards.pop()

  discardThese: (cards) -> @discard.place cards

class Board
  constructor: ->
    @villagers = new Tableau([
      new Villager(FARMER.create()),
      new Villager(FARMER.create())
    ])

    for villager in @villagers.cards
      villager.acted = false

    @technologies = new Tableau(TECHNOLOGY_SAMPLER)
    @buildings = new Tableau([
      new Building(FARM.create(), 2),
      new Building(FARM.create(), 2),
    ])

    @revealed = new Tableau()

    @professionDeck = new Deck(VILLAGER_DECK)
    @technologyDeck = new Deck(TECHNOLOGY_DECK)
    @buildingDeck = new Deck(BUILDING_DECK)

    @professionDeck.shuffle()
    @technologyDeck.shuffle()
    @buildingDeck.shuffle()

    @foodReserves = 20
    @goldReserves = 0
    @woodReserves = 0

class ConsoleBoard extends Board
  constructor: (@rl) ->
    super

    @interact = {}

    @interact.optionalSelect = (area, verify, decline, callback) =>
      viableCards = area.cards.filter (verify ? (-> true))

      if viableCards.length is 0
        do decline

      else
        options = []
        for card, i in viableCards
          options.push " #{i} | #{card.render().replace(/\n/g, '\n    ')}"

        recurrent = =>
          @rl.question 'Select one (\'n\' for none):\n' + options.join('\n') + '\n> ', (result) ->
            if result is 'n'
              do decline
            else if Number(result) in [0...viableCards.length]
              callback viableCards[Number(result)]
            else
              do recurrent
        do recurrent

    @interact.menu = (options) =>
      results = []
      display = []
      i = 0
      for key, val of options
        display.push " #{i} | #{key}"
        results.push val
        i += 1

      recurrent = =>
        @rl.question 'Select one:\n' + display.join('\n') + '\n> ', (answer) ->
          if Number(answer) in [0...results.length]
            do results[Number(answer)]
          else
            do recurrent
      do recurrent

  render: ->
    lines = []
    lines.push `'\033[2J\033[1;1H'`
    lines.push "#{@foodReserves} FOOD, #{@woodReserves} WOOD, #{@goldReserves} GOLD"
    lines.push 'VILLAGERS'
    lines.push '========='

    for villager, i in @villagers.cards
      lines.push '  ' + villager.render()

    lines.push ''
    lines.push 'BUILDINGS'
    lines.push '========='

    for building, i in @buildings.cards
      lines.push '  ' + building.render()

    lines.push ''
    lines.push 'TECHNOLOGIES'
    lines.push '============'

    for tech, i in @technologies.cards
      lines.push '  ' + tech.render().replace(/\n/g, '\n  ')
    return lines.join '\n'

generate_deck = (pairs) ->
  deck = []
  for pair in pairs
    for [1..pair[1]]
      deck.push pair[0].create()
  return deck

# THE COMMON ACTIONS
# ==================

death = (context, villager) ->
  villager.age = 0
  context.board.professionDeck.discardThese villager

design = (n, context, cb) ->
  # Draw and reveal n cards.
  for [1..n]
    context.board.revealed.place context.board.buildingDeck.draw()

  context.interact.optionalSelect board.revealed, null, (->
    context.board.buildingDeck.discardThese board.revealed.wipe()
    do cb
  ), (selected) ->
    # Remove the selected card from the revealed tableau
    context.board.revealed.remove selected

    # Add it to the buildings tableau
    context.board.buildings.place new Building selected

    # Discard the other building cards
    context.board.buildingDeck.discardThese context.board.revealed.wipe()

    do cb

build = (context, cb) ->
  if context.board.woodReserves >= 1
    context.interact.optionalSelect board.buildings, ((b) -> b.progress < b.type.bulk), cb, (selected) ->
      context.board.woodReserves -= 1
      selected.progress += 1

      # Handle build hooks
      recurrent = (rcb, i = 0) ->
        if i is context.board.technologies.cards.length
          do rcb
        else
          card = context.board.technologies.cards[i]
          if card.hooks['Whenever you Build']?
            console.log 'TECHNOLOGY ACTIVATES:', card.name
            card.hooks['Whenever you Build'].apply context.subcontext(card, card), -> recurrent rcb, i + 1
          else
            recurrent rcb, i + 1

      recurrent cb
  else
    do cb

educate = (n, context, cb) ->
  if context.board.foodReserves >= 1
    # Ask the player to select a villager to educate
    context.interact.optionalSelect board.villagers, ((v) -> not v.acted), cb, (villager) ->
      context.board.foodReserves -= 1
      villager.age += 1
      villager.acted = true

      educate_raw n, context, cb, villager
  else
    do cb

educate_raw = (n, context, cb, villager) ->
  # Draw and reveal n cards.
  for [1..n]
    context.board.revealed.place context.board.professionDeck.draw()

  # Ask the player to select a new profession
  context.interact.optionalSelect board.revealed, null, (->
    context.board.professionDeck.discardThese context.board.revealed.wipe()
    do cb
  ), (selected) ->
    # Remove the selected card from the revealed tableau
    context.board.revealed.remove selected

    # Discard the rest
    context.board.professionDeck.discardThese context.board.revealed.wipe()

    # Remove the uneducated villager's profession
    context.board.professionDeck.discardThese villager.profession

    # Replace the profession with the selected card
    villager.profession = selected

    do cb

research = (n, context, cb) ->
  # Draw and reveal n cards.
  for [1..n]
    context.board.revealed.place context.board.technologyDeck.draw()

  console.log 'REVEALED:'
  console.log '========='
  context.board.revealed.cards.forEach (card) -> console.log '  ' + card.render().replace(/\n/g, '\n  ')
  console.log ''

  context.interact.menu {
    'Okay': ->
      context.interact.optionalSelect board.revealed, ((card) ->
        card.requirement.fn(context) and context.board.technologies.cards.every((tech) -> tech.name isnt card.name)
      ), (->
        context.board.technologyDeck.discardThese context.board.revealed.wipe()
        do cb
      ), (selected) ->
        # Remove the selected card from the revealed tableau
        context.board.revealed.remove selected

        # Add the new research
        context.board.technologies.place selected

        # Discard the other researches
        context.board.technologyDeck.discardThese context.board.revealed.wipe()

        do cb
  }

# THE BUILDINGS
# ====================
FARM = new BuildingTypeTemplate(
  'Farm',
  2,
  [],
  new Action(
    'Choose one: Put 2 Food on this card, or take all the Food on this card. This card can\'t store more than 10 Food.',
    (context, cb) ->
      if context.textCard.food < 10
        context.interact.menu {
          'Place 2 Food': ->
            context.textCard.food += 2
            context.textCard.food = Math.min context.textCard.food, 10
            do cb
          'Take Food': ->
            context.board.foodReserves += context.textCard.food
            context.textCard.food = 0
            do cb
        }
      else
        context.board.foodReserves += context.textCard.food
        context.textCard.food = 0
        do cb
  )
)

GRANARY = new BuildingTypeTemplate(
  'Granary',
  2,
  [],
  new Action(
    'Take one food. *Increases your Food storage by 5.*'
    (context, cb) ->
      context.board.foodReserves += 1
      do cb
  ),
  {
    food: 5
    wood: 0
    gold: 0
  }
)

LUMBER_HUT = new BuildingTypeTemplate(
  'Lumber Hut',
  3,
  [],
  new Action(
    'Choose one: Put 1 Wood on this card, or take 2 Wood from this card.'
    (context, cb) ->
      context.interact.menu {
        'Place 1 Wood': ->
          context.textCard.wood += 1
          do cb
        'Take 2 Wood': ->
          context.board.woodReserves += Math.min 2, context.textCard.wood
          context.textCard.wood = Math.max 0, context.textCard.wood - 2
          do cb
      }
  )
)

MINE = new BuildingTypeTemplate(
  'Mine',
  4,
  [],
  new Action(
    'Choose one: If there is Gold here, take one. Otherwise, put a Gold here.'
    (context, cb) ->
      if context.textCard.gold >= 1
        context.board.goldReserves += 1
        context.textCard.gold -= 1
      else
        context.textCard.gold += 1

      do cb
  )
)

SCHOOLHOUSE = new BuildingTypeTemplate(
  'Schoolhouse',
  5,
  [],
  new Action(
    'Educate(1).',
    (context, cb) ->
      educate 1, context, cb
  )
)

LIBRARY = new BuildingTypeTemplate(
  'Library',
  6,
  [],
  new Action(
    'Research(2).'
    (context, cb) ->
      research 1, context, cb
  )
)

TOWN_HALL = new BuildingTypeTemplate(
  'Town Hall',
  6,
  [],
  new Action(
    'Design(1).',
    (context, cb) ->
      design 1, context, cb
  )
)

BUILDING_DECK = generate_deck [
  [FARM, 30]
  [GRANARY, 20]
  [LUMBER_HUT, 20]
  [MINE, 20]
  [SCHOOLHOUSE, 10]
  [LIBRARY, 10]
  [TOWN_HALL, 10]
]

# THE PROFESSIONS
# ===============

VILLAGER = new ProfessionTemplate(
  'Villager',
  new Action('', (context, cb) -> do cb)
)

FREELANCER = new ProfessionTemplate(
  'Freelancer',
  new Action(
    'Reveal a villager card. This card performs its action.',
    (context, cb) ->
      imitatee = context.board.professionDeck.draw()
      console.log 'Imitating: ', imitatee.name, imitatee.action.text
      context.interact.menu {
        'Okay': -> imitatee.action.apply context.subcontext(imitatee, context.actingCard), cb
      }
  )
)

HOUSEWIFE = new ProfessionTemplate(
  'Housewife',
  new Action(
    'Pick another villager. You may pay 2 Food to remove 1 age from them.',
    (context, cb) ->
      if context.board.foodReserves >= 2
        context.interact.optionalSelect context.board.villagers, ((v) -> v.age > 0), cb, (villager) ->
          context.board.foodReserves -= 2
          villager.age -= 1
          do cb
      else
        do cb
  )
)

DOCTOR = new ProfessionTemplate(
  'Doctor',
  new Action(
    'Pick another villager. Remove 1 age from them. You may pay 1 Gold to repeat this text.',
    (context, cb) ->
      # Here we define a recursive text
      recurrent = ->
        context.interact.optionalSelect context.board.villagers, ((v) -> v.age > 0), cb, (villager) ->
          villager.age -= 1

          if context.board.goldReserves >= 1
            context.interact.menu {
              'Repeat this text': recurrent
              'Done': cb
            }
          else
            do cb
      do recurrent
  )
)

SCHOLAR = new ProfessionTemplate(
  'Scholar',
  new Action(
    'Choose one: replace my profession with a profession in the discard pile.'
    (context, cb) ->
      context.interact.optionalSelect context.board.professionDeck.discard, null, cb, (replacement) ->
        # Remove the replacement from the discard pile
        context.board.professionDeck.discard.remove replacement

        # Discard the current profession
        context.board.professionDeck.discardThese context.actingCard.profession

        # Replace the profession
        context.actingCard.profession = replacement

        do cb
  )
)

GRAVEDIGGER = new ProfessionTemplate(
  'Gravedigger',
  new Action(
    'If a villager is age 10, gain 2 Gold.',
    (context, cb) ->
      if context.board.villagers.cards.some((villager) -> villager.age is 10)
        context.board.goldReserves += 2
      do cb
  )
)

OVERSEER = new ProfessionTemplate(
  'Overseer',
  new Action(
    'Pick another villager and age it. That card executes its own action.'
    (context, cb) ->
      if context.board.foodReserves >= 1
        context.interact.optionalSelect context.board.villagers, null, cb, (villager) ->
          context.board.foodReserves -= 1
          villager.age += 1
          villager.profession.action.apply context.subcontext(villager.profession, villager), ->
            do cb
      else
        do cb
  )
)

TRAVELER = new ProfessionTemplate(
  'Passing Traveler',
  new Action(
    'Research(1). Educate(1). Gain 1 Food, 1 Wood, and 1 Gold. Reveal a profession and replace my profession with it.',
    (context, cb) ->
      research 1, context, ->
        educate 1, context, ->
          context.board.foodReserves += 1
          context.board.goldReserves += 1
          context.board.woodReserves += 1

          # Replace the Traveler
          context.actingCard.profession = context.board.professionDeck.draw()
          context.board.professionDeck.discardThese context.textCard

          do cb
  )
)

MONK = new ProfessionTemplate(
  'Monk',
  new Action(
    'Remove one age from me',
    (context, cb) ->
      if context.actingCard.age > 0
        context.actingCard.age -= 1
      do cb
  )
)

PRIEST = new ProfessionTemplate(
  'Priest',
  new Action(
    'Gain 1 Gold per villager of age 0 or 10 this turn.',
    (context, cb) ->
      context.board.goldReserves += (
        context.board.villagers.cards.filter((v) -> v.age in [0, 10]).length
      )
      do cb
  )
)

PROFESSOR = new ProfessionTemplate(
  'Professor',
  new Action(
    'If I am age 5 or more, choose one: Research(5) or Educate(5). Otherwise, Research(1).',
    (context, cb) ->
      if context.actingCard.age >= 5
        context.interact.menu {
          'Research(5)': ->
            research 5, context, cb
          'Educate(5)': ->
            educate 5, context, cb
        }
      else
        research 1, context, cb
  )
)

TEACHER = new ProfessionTemplate(
  'Teacher',
  new Action(
    'Educate(4).',
    (context, cb) ->
      educate 4, context, cb
  )
)

LECTURER = new ProfessionTemplate(
  'Lecturer',
  new Action(
    'Do this up three times: Educate(1).',
    (context, cb) ->
      recurrent = (n) ->
        if n is 0
          do cb
        else
          context.interact.menu {
            'Educate': -> educate 1, context, -> recurrent(n - 1)
            'Done': -> do cb
          }

      recurrent 3
  )
)

TUTOR = new ProfessionTemplate(
  'Tutor',
  new Action(
    'Pay 1 Gold. If you do, Educate(7).',
    (context, cb) ->
      if context.board.goldReserves >= 1
        context.board.goldReserves -= 1
        educate 7, context, cb
      else
        do cb
  )
)

TRAINER = new ProfessionTemplate(
  'Trainer',
  new Action(
    'Pick a villager that has not yet acted. You may Educate(1) that villager any number of times. '
    (context, cb) ->
      context.interact.optionalSelect context.board.villagers, ((v) -> not v.acted), cb, (villager) ->
        recurrent = ->
          if context.board.foodReserves >= 1
            context.interact.menu {
              'Educate': ->
                # Age the villager
                context.board.foodReserves -= 1
                villager.age += 1
                villager.acted = true

                educate_raw 1, context, recurrent, villager
              'Done': cb
            }
          else
            do cb
        do recurrent
  )
)

TINKERER = new ProfessionTemplate(
  'Tinkerer',
  new Action(
    'Choose one: gain 1 Wood, or pay 1 Wood to Build, or pay 2 Wood to Research(2), or pay 2 Wood to Design(2).',
    (context, cb) ->
      if context.board.woodReserves >= 2
        context.interact.menu {
          'Gain 1 Wood': ->
            context.board.woodReserves += 1
            do cb
          'Build': ->
            context.board.woodReserves -= 1
            build context, cb
          'Research(2)': ->
            context.board.woodReserves -= 2
            research 2, context, cb
          'Design(2)': ->
            context.board.woodReserves -= 2
            design 2, context, cb
        }
      else
        context.board.woodReserves += 1
        do cb
  )
)

RESEARCHER = new ProfessionTemplate(
  'Researcher',
  new Action(
    'Research(3)',
    (context, cb) ->
      research 3, context, cb
  )
)

PHILOSOPHER = new ProfessionTemplate(
  'Philosopher',
  new Action(
    'Look at the top 5 research cards. You may put one on top. Discard the rest.',
    (context, cb) ->
      for [1..5]
        context.board.revealed.place context.board.technologyDeck.draw()

      context.interact.optionalSelect context.board.revealed, null, (->
        context.board.technologyDeck.discardThese context.board.revealed.wipe()
        do cb
      ), (selected) ->
        context.board.revealed.remove selected
        context.board.technologyDeck.cards.push selected
        context.board.technologyDeck.discardThese context.board.revealed.wipe()
        do cb
  )
)

HISTORIAN = new ProfessionTemplate(
  'Historian',
  new Action(
    'Look through the Research discard pile and put one research on top of the deck.',
    (context, cb) ->
      context.interact.optionalSelect context.board.technologyDeck.discard, null, cb, (selected) ->
        context.board.technologyDeck.discard.remove selected
        context.board.technologyDeck.cards.push selected
  )
)

MATHEMATICIAN = new ProfessionTemplate(
  'Mathematician',
  new Action(
    'If I am age 9 or 10, Research(10).'
    (context, cb) ->
      if context.actingCard.age in [9, 10]
        research 10, context, cb
      else
        do cb
  )
)

CHEMIST = new ProfessionTemplate(
  'Chemist',
  new Action(
    'Choose one: pay 1 Wood and 1 Food to gain 1 Gold, or pay 1 Gold to Research(5).',
    (context, cb) ->
      options = {}
      if context.board.woodReserves >= 1 and context.board.foodReserves >= 1
        options['Gain 1 Gold'] = ->
          context.board.woodReserves -= 1
          context.board.foodReserves -= 1
          do cb
      if context.board.goldReserves >= 1
        options['Research(5)'] = ->
          context.board.goldReserves -= 1
          research 5, context, cb

      context.interact.menu options
  )
)

ARCHITECT = new ProfessionTemplate(
  'Architect',
  new Action(
    'Design(4).'
    (context, cb) ->
      design 5, context, cb
  )
)

SURVEYOR = new ProfessionTemplate(
  'Surveyor',
  new Action(
    'Design(2).',
    (context, cb) ->
      design 2, context, cb
  )
)

ENGINEER = new ProfessionTemplate(
  'Engineer',
  new Action(
    'Design(2). You may pay 1 Wood to repeat this text.',
    (context, cb) ->
      recurrent = ->
        design 2, context, ->
          if context.board.woodReserves >= 2
            context.interact.menu {
              'Repeat': ->
                context.board.woodReserves -= 2
                do recurrent
              'Done': cb
            }
          else
            do cb
      do recurrent
  )
)

FOREMAN = new ProfessionTemplate(
  'Foreman',
  new Action(
    'Design(2). Build(2).',
    (context, cb) ->
      design 2, context, ->
        build context, ->
          build context, cb
  )
)

BUILDER = new ProfessionTemplate(
  'Builder',
  new Action(
    'Build twice.',
    (context, cb) ->
      build context, -> build context, cb
  )
)

MASON = new ProfessionTemplate(
  'Mason',
  new Action(
    'Gain 1 Wood. Build.',
    (context, cb) ->
      board.context.woodReserves += 1
      build context, cb
  )
)

WOODSMAN = new ProfessionTemplate(
  'Woodsman',
  new Action(
    'Choose one: Gain 2 Wood, or Build twice.',
    (context, cb) ->
      context.interact.menu {
        'Gain 2 Wood': ->
          context.board.woodReserves += 2
          do cb
        'Build twice': ->
          build context, ->
            build context, cb
      }
  )
)

FARMER = new ProfessionTemplate(
  'Farmer',
  new Action(
    'Gain 1 Food. Put 1 Food on each Farm you have.',
    (context, cb) ->
      context.board.foodReserves += 1

      context.board.buildings.cards.forEach (building) ->
        if building.type.name is 'Farm' and building.progress >= building.type.bulk
          building.food += 1
          building.food = Math.min building.food, 10

      do cb
  )
)

MINER = new ProfessionTemplate(
  'Miner',
  new Action(
    'Put 1 Gold on each of your Mines.'
    (context, cb) ->
      context.board.buildings.cards.forEach (building) ->
        if building.type.name is 'Mine' and building.progress >= building.type.bulk
          building.gold += 1
          building.gold = Math.min building.food, 10

      do cb
  )
)

TRADER = new ProfessionTemplate(
  'Trader',
  new Action(
    'Pay 1 Gold. If you do, choose one: gain 5 Food, or gain 5 Wood.',
    (context, cb) ->
      if context.board.goldReserves >= 1
        context.board.goldReserves -= 1
        context.interact.menu {
          '5 Food': ->
            context.board.foodReserves += 5
            do cb
          '5 Wood': ->
            context.board.woodReserves += 5
            do cb
        }
      else
        do cb
  )
)

PANNER = new ProfessionTemplate(
  'Panner',
  new Action(
    'Choose one: gain 1 Wood, or pay 3 Wood to gain 1 Gold.',
    (context, cb) ->
      if context.board.woodReserves >= 3
        context.interact.menu {
          'Gain 1 Wood': ->
            context.board.woodReserves += 1
            do cb
          'Gain 1 Gold': ->
            context.board.woodReserves -= 3
            context.board.goldReserves += 1
            do cb
        }
      else
        context.board.woodReserves += 1
        do cb
  )
)

LUMBERJACK = new ProfessionTemplate(
  'Lumberjack',
  new Action(
    'Gain 2 Wood.'
    (context, cb) ->
      context.board.woodReserves += 2
      do cb
  )
)

FORESTER = new ProfessionTemplate(
  'Forester',
  new Action(
    'Pay 2 Food to gain 4 Wood.',
    (context, cb) ->
      if context.board.foodReserves >= 2
        context.board.foodReserves -= 2
        context.board.woodReserves += 4
        do cb
  )
)

VILLAGER_DECK = generate_deck [
  [VILLAGER, 10],
  [FREELANCER, 7],
  [HOUSEWIFE, 5],
  [DOCTOR, 3],
  [SCHOLAR, 3],
  [GRAVEDIGGER, 3],
  [OVERSEER, 3],
  [TRAVELER, 7],
  [MONK, 3],
  [PRIEST, 3],
  [PROFESSOR, 3],
  [TEACHER, 5],
  [LECTURER, 3],
  [TUTOR, 5],
  [TRAINER, 3],
  [TINKERER, 3],
  [RESEARCHER, 3],
  [PHILOSOPHER, 3],
  [HISTORIAN, 3],
  [MATHEMATICIAN, 3],
  [CHEMIST, 3],
  [ARCHITECT, 5],
  [SURVEYOR, 5],
  [ENGINEER, 5],
  [FOREMAN, 5],
  [WOODSMAN, 7],
  [BUILDER, 10],
  [FARMER, 13],
  [MINER, 5],
  [TRADER, 3],
  [PANNER, 3],
  [LUMBERJACK, 5],
  [FORESTER, 3]
]

DUMMY_TECH = {
  create: ->
    new Technology(
      generateBadIdeaName(),
      new Requirement(
        'This is a bad idea. You cannot research this.',
        (-> false)
      )
      {},
      null
    )
}

TWISTS = [
  'Upside-Down',
  'Inside-Out',
  'Backwards',
  'Invisible',
  'Flying',
  'Handheld',
  'Self-Aware',
  'Wearable',
  'Edible',
  'Rideable',
  'Ant-Sized',
  'Elephant-Sized',
  'Uber, But For',
  'Yelp, But For'
]

OBJECTS = [
  'Wheelbarrows',
  'Trees',
  'Teacups',
  'Guitars',
  'Chopsticks',
  'Baskets',
  'Chairs',
  'Water Bottles',
  'Forks',
  'Knives',
  'Cows',
  'Pigs'
]

generateBadIdeaName = ->
  "#{TWISTS[Math.floor Math.random() * TWISTS.length]} #{OBJECTS[Math.floor Math.random() * OBJECTS.length]}"

IRRIGATION = new TechnologyTemplate(
  'Irrigation',
  new Requirement(
    '4 Farms',
    ((context) ->
      context.board.buildings.cards.filter((x) -> x.progress is x.type.bulk and x.type.name is 'Farm').length >= 4
    )
  ),
  {
    'End of turn': new Action(
      'Put one Food on each of your farms.',
      (context, cb) ->
        context.board.buildings.cards.forEach (building) ->
          if building.type.name is 'Farm' and building.progress >= building.type.bulk
            building.food += 1
            building.food = Math.min building.food, 10
        do cb
    )
  },
  null
)

CROP_ROTATION = new TechnologyTemplate(
  'Crop Rotation',
  new Requirement(
    '2 Farms, one empty and one with Food.',
    ((context) ->
      context.board.buildings.cards.some((x) -> x.progress is x.type.bulk and x.type.name is 'Farm' and x.food is 0) and context.board.buildings.cards.some((x) -> x.progress is x.type.bulk and x.type.name is 'Farm' and x.food >= 1)
    )
  ),
  {
    'End of turn': new Action(
      'Put 2 Food on each of your empty farms.',
      (context, cb) ->
        context.board.buildings.cards.forEach (building) ->
          if building.type.name is 'Farm' and building.progress >= building.type.bulk and building.food is 0
            building.food = 2
        do cb
    )
  }
)

FORAGING = new TechnologyTemplate(
  'Foraging',
  new Requirement(
    '5 Wood and all your Farms are empty',
    ((context) ->
      context.board.woodReserves >= 5 and context.board.buildings.cards.every((building) -> building.type.name isnt 'Farm' or building.food is 0)
    )
  ),
  {},
  new Action(
    'Take one Food.',
    (context, cb) ->
      context.board.foodReserves += 1
      do cb
  )
)

TOOLS = new TechnologyTemplate(
  'Tools',
  new Requirement(
    '5 Wood, 3 unfinished buildings',
    ((context) ->
      context.board.woodReserves >= 5 and context.board.buildings.cards.filter((x) -> x.bulk < x.progress).length >= 3
    )
  ),
  {},
  new Action(
    'Build.'
    (context, cb) ->
      build context, cb
  )
)

GEOLOGY = new TechnologyTemplate(
  'Geology',
  new Requirement(
    'Three Mines, each with Gold on them',
    ((context) ->
      context.board.buildings.cards.filter((x) -> x.type.name is 'Mine' and x.bulk is x.progress and x.gold >= 1).length >= 3
    )
  ),
  {},
  new Action(
    'Put 3 Gold on a Mine.',
    ((context, cb) ->
      context.interact.optionalSelect board.buildings, ((b) -> b.type.name is 'Mine' and b.progress is b.type.bulk), cb, (mine) ->
        mine.gold += 3
        do cb
    )
  )
)

MINING_EXPLOSIVES = new TechnologyTemplate(
  'Mining Explosives',
  new Requirement(
    'Three mines, all empty.',
    ((context) ->
      context.board.buildings.cards.filter((x) -> x.type.name is 'Mine' and x.bulk is x.progress and x.gold is 1).length >= 3
    )
  ),
  {},
  new Action(
    'Remove all progress from a finished Mine. Take 7 Gold.',
    ((context, cb) ->
      context.interact.optionalSelect board.buildings, ((b) -> b.type.name is 'Mine' and b.progress is b.type.bulk), cb, (mine) ->
        mine.progress = 0
        context.board.gold += 7

        do cb
    )
  )
)

NURSING = new TechnologyTemplate(
  'Nursing',
  new Requirement(
    '3 villagers, each of age 0, 1, or 2.',
    ((context) ->
      context.board.villagers.cards.filter((x) -> x.age in [0, 1, 2]).length >= 3
    )
  ),
  {
    'End of turn': new Action(
      'Educate(2) each newborn villager.',
      ((context, cb) ->
        children = context.board.villagers.cards.filter (v) -> v.age is 0

        recurrent = (rcb, i = 0) ->
          if i is children.length
            do rcb
          else
            educate_raw 2, context, (->
              recurrent rcb, i + 1
            ), children[i]

        recurrent cb
      )
    )
  },
  null
)

PATENTS = new TechnologyTemplate(
  'Patents',
  new Requirement(
    '10 Technologies',
    ((context) ->
      context.board.technologies.cards.length >= 10
    )
  ),
  {},
  new Action(
    'Research(1)',
    ((context, cb) -> research 1, context, cb)
  )
)

UTOPIA = new TechnologyTemplate(
  'Utopia',
  new Requirement(
    '10 Villagers. 15 Buildings. A total of 40 bulk among your buildings. 40 Food, 20 Wood, and 10 Gold.',
    ((context) ->
      context.board.villagers.cards.length >= 10 and
      context.board.buildings.cards.length >= 10 and
      context.board.buildings.cards.map((x) -> x.bulk).reduce((a, b) -> a + b) >= 40 and
      context.board.foodReserves >= 40 and
      context.board.woodReserves >= 20 and
      context.board.goldReserves >= 10
    )
  ),
  {
    'End of turn': new Action(
      'Win the game.',
      ((context, cb) ->
        console.log 'You win!'
        process.exit 0
      )
    )
  },
  null
)

WORK_ANIMALS = new TechnologyTemplate(
  'Work Animals',
  new Requirement(
    '10 Food per building you have',
    ((context) ->
      context.board.foodReserves >= context.board.buildings.cards.filter((x) -> x.progress is x.type.bulk).length * 10
    )
  ),
  {
    'End of turn': new Action(
      'For each of your buildings, you may pay 1 Food to take its action.',
      ((context, cb) ->
        buildings = board.buildings.cards.filter((x) -> x.progress >= x.type.bulk and not x.acted)
        recurrent = (i = 0) ->
          if context.board.foodReserves >= 1 and i < buildings.length
            building = buildings[i]
            console.log building.render()
            context.interact.menu {
              'Take action': ->
                context.board.foodReserves -= 1
                building.acted = true
                context = new ActionContext board, building, context.actingCard
                building.type.action.apply context, -> recurrent i + 1
              'Pass': ->
                recurrent i + 1
            }
          else
            do cb
        do recurrent
      )
    )
  }
)

CRANE = new TechnologyTemplate(
  'Crane',
  new Requirement(
    '7 Wood, 3 unfinished buildings, and 10 total progress on buildings.',
    ((context) ->
      context.board.woodReserves >= 7 and
      context.board.buildings.cards.filter((x) -> x.progress < x.type.bulk).length >= 3 and
      context.board.buildings.cards.map((x) -> x.progress).reduce((a, b) -> a + b) >= 10
    )
  ),
  {
    'Whenever you Build': new Action(
      'Build (this card does not activate itself)',
      (context, cb) ->
        unless context.textCard._disableActivation
          context.textCard._disableActivation = true
          build context, ->
            context.textCard._disableActivation = false
            do cb
        else
          do cb
    )
  },
  null
)

SCAFFOLDING = new TechnologyTemplate(
  'Scaffolding',
  new Requirement(
    '3 unfinished buildings, each at least 5 in bulk.',
    (context) ->
      context.buildings.cards.filter((x) -> x.progress < x.type.bulk and x.type.bulk >= 5).length >= 3
  ),
  {
    'Whenever you Build': new Action(
      'Put 1 Wood here',
      (context, cb) ->
        context.textCard.wood += 1
        do cb
    )
  },
  new Action(
    'Build all the wood here.',
    (context, cb) ->
      recurrent = ->
        if context.textCard.wood >= 1
          context.textCard.wood -= 1
          context.board.woodReserves += 1
          build context, recurrent
        else
          do cb

      do recurrent
  )
)

TECHNOLOGY_SAMPLER = []

TECHNOLOGY_DECK = generate_deck [
  [DUMMY_TECH, 110]
  [FORAGING, 10]
  [TOOLS, 10]
  [CRANE, 10]
  [SCAFFOLDING, 10]
  [GEOLOGY, 10]
  [MINING_EXPLOSIVES, 10]
  [CROP_ROTATION, 10]
  [IRRIGATION, 10]
  [NURSING, 10]
  [PATENTS, 10]
  [WORK_ANIMALS, 10]
  [UTOPIA, 1]
]


# TO EXECUTE A TURN
singleVillager = (board, villager, cb) ->
  menu = {
    'Execute profession action': ->
      context = new ActionContext board, villager.profession, villager
      villager.profession.action.apply context, cb
    'Execute a building action': ->
      board.interact.optionalSelect board.buildings, ((b) -> b.progress >= b.type.bulk and not b.acted), cb, (building) ->
        building.acted = true
        context = new ActionContext board, building, villager
        building.type.action.apply context, cb
  }

  if board.technologies.cards.filter((tech) -> tech.action?).length >= 1
    menu['Execute a technology action'] = ->
      board.interact.optionalSelect board.technologies, ((tech) -> tech.action?), cb, (tech) ->
        context = new ActionContext board, tech, villager
        tech.action.apply context, cb

  if board.foodReserves >= 4
    menu['Give birth'] = ->
      board.foodReserves -= 4
      board.villagers.place new Villager board.professionDeck.draw()
      do cb

  board.interact.menu menu

villagerRecurrent = (board, cb) ->
  console.log board.render()
  console.log ''

  if board.foodReserves >= 1
    board.interact.optionalSelect board.villagers, ((v) -> not v.acted), cb, (villager) ->
      villager.acted = true
      villager.age += 1
      board.foodReserves -= 1

      singleVillager board, villager, ->
        # Cap resources
        board.foodReserves = Math.min board.foodReserves, 20 + board.buildings.cards.filter((x) -> x.progress >= x.type.bulk).map((x) -> x.type.storage.food).reduce((a, b) -> a + b)
        board.woodReserves = Math.min board.woodReserves, 10 + board.buildings.cards.filter((x) -> x.progress >= x.type.bulk).map((x) -> x.type.storage.wood).reduce((a, b) -> a + b)
        board.goldReserves = Math.min board.goldReserves, 5 + board.buildings.cards.filter((x) -> x.progress >= x.type.bulk).map((x) -> x.type.storage.gold).reduce((a, b) -> a + b)

        villagerRecurrent board, cb
  else
    do cb

executeTurn = (board, cb) ->
  if board.villagers.cards.length > 0
    if board.foodReserves > 0
      villagerRecurrent board, ->
        # Process end-of-turn hooks
        recurrent = (rcb, i = 0) ->
          if i is board.technologies.cards.length
            do rcb
          else
            card = board.technologies.cards[i]
            if card.hooks['End of turn']?
              console.log 'TECHNOLOGY ACTIVATES:', card.name
              card.hooks['End of turn'].apply new ActionContext(board, card, card), -> recurrent rcb, i + 1
            else
              recurrent rcb, i + 1

        recurrent ->
          # Clean-up.
          removals = board.villagers.cards.filter (x) -> (not x.acted) or x.age >= 10
          board.professionDeck.discardThese removals.map (x) -> x.profession
          board.villagers.cards = board.villagers.cards.filter (x) -> x.acted and x.age < 10

          # 2 De-act all villagers
          board.villagers.cards.forEach (villager) -> villager.acted = false

          # 2 De-act all buildings
          board.buildings.cards.forEach (building) -> building.acted = false

          do cb

    else
      console.log 'You ran out of food. You lose.'
      process.exit 0

  else
    console.log 'All your villagers died. You lose.'
    process.exit 0

# Play the game!
rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
})
board = new ConsoleBoard(rl)

recurrent = ->
  executeTurn board, recurrent

do recurrent
