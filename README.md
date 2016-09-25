Villages
========

In villages, you manage a tiny nomadic family settling down and starting to farm for the first time. You'll guide them from being two old farmers on a plot of land to being a sprawling technologically-advanced city-state -- or the family line will die out of hunger. One of those two.

Villages is a solitaire card game. You manage a tableau of villagers of different professions, which will slowly rotate as villagers die of old age and more villagers are born. You will collect and spend three resources -- Food (which your villagers eat every turn), Wood (used for building buildings), and Gold (premium resource for special actions).

At the beginning of the game, shuffle each of the three decks (Professions, Buildings, and Technologies). Put 2 Farmers on your Villager tableau, and 2 Farms on your Buildings tableau. Put 2 Wood on each Farm.

Each turn, do the following any number of times:
  - Pick a villager in your villager tableau who hasn't acted yet.
  - Move one food from your stockpile to that villager. This means the villager has aged one more unit.
  - That villager may:
    - Perform the action on its card (its profession),
    - Take an Alternate Action somewhere on the board. These are provided by Buildings and Technologies. Building Alternate Actions can only be taken once per turn, while Technology Alternate Actions may be taken any number of times.
    - Give birth. Giving birth costs 4 Food. Draw a card from the Professions deck and put it into your Villagers tableau. That card can't be used yet this turn.

At the end of your turn: remove any villagers from your tableau who didn't act (you couldn't feed them), or have 10 food on them (they are dying of old age).

Common Actions
--------------

Cards will mention the actions `Research(n)`, `Design(n)`, `Educate(n)`, and `Build`. These are common actions described as follows:
  - `Research(n)`: look at the top `n` cards from the Technologies deck. You may pick one. If you fulfill its requirements, immediately put it into your Technology tableau. Otherwise, discard it. Discard the rest.
  - `Educate(n)`: pick a villager on your Villagers tableau that hasn't acted yet. Age it by one, and it has now acted. Look at the top `n` cards in the Professions deck. You may pick one and replace the chosen villager's profession with it, discarding the rest. Otherwise, discard them all.
  - `Design(n)`: look at the top `n` cards from the Buildings deck. You may pick one and put it onto your Buildings tableau. Discard the rest. Note: this is just a building plan; it can't be used until it has been built by Build actions.
  - `Build`: If you have at least 1 Wood, put 1 Wood onto any building in your Buildings tableau. Buildings cannot be used until they have Wood on them equal to their Bulk number, which is listed on the card.

Losing and Winning
------------------

There are two lose conditions:
  1. You have no food.
  2. You have no villagers.

(clearly, in either case, you cannot continue the game).

The win condition is to research the technology `Utopia`. This is a technology which requires you to have 20 villagers out at once, 20 buildings, and 30 other technologies, and costs 50 of each resource.
