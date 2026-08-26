import 'package:meta/meta.dart';

/// One block of an article.
///
/// Kept deliberately small: a heading, prose, a list, or a figure the reader can
/// check against their own plan. The renderer decides how each looks, so an
/// article stays readable text rather than embedded markup.
@immutable
sealed class GuideBlock {
  const GuideBlock();
}

/// A paragraph of ordinary prose.
final class GuideText extends GuideBlock {
  const GuideText(this.text);

  final String text;
}

/// A sub-heading inside an article.
final class GuideHeading extends GuideBlock {
  const GuideHeading(this.text);

  final String text;
}

/// A short list of points, rendered with shelf-edge bullets.
final class GuidePoints extends GuideBlock {
  const GuidePoints(this.points);

  final List<String> points;
}

/// A figure worth pulling out of the prose, such as a threshold the app uses.
final class GuideFigure extends GuideBlock {
  const GuideFigure({required this.value, required this.caption});

  final String value;
  final String caption;
}

/// A practical article.
@immutable
class GuideArticle {
  const GuideArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.readMinutes,
    required this.blocks,
  });

  final String id;
  final String title;

  /// One line for the list, plain enough to be useful on its own.
  final String summary;

  final int readMinutes;
  final List<GuideBlock> blocks;
}

/// Reference reading on loading shelves safely.
///
/// The articles explain the reasoning the analysis uses, with the same figures,
/// so a warning on a plan can be understood rather than merely obeyed. All of it
/// ships with the app and reads offline.
abstract final class StorageGuide {
  static const GuideArticle weightLow = GuideArticle(
    id: 'weight-low',
    title: 'Heavy things belong low',
    summary: 'Why the bottom shelf does the real work, and what happens when it does not.',
    readMinutes: 2,
    blocks: [
      GuideText(
        'A loaded shelf stays upright because its combined weight sits low and '
        'near the middle. Raise that weight and the same unit becomes easier to '
        'tip, without anything about the frame having changed.',
      ),
      GuideHeading('The centre of mass'),
      GuideText(
        'Every object contributes weight at its own height. Averaged together, '
        'those heights give one point: the centre of mass. It is the single '
        'number that best predicts whether a unit will stay put when it is '
        'knocked, leaned on, or loaded unevenly.',
      ),
      GuideFigure(
        value: '60%',
        caption:
            'Above this height, measured up the structure, this app starts '
            'flagging a plan as top-heavy.',
      ),
      GuideText(
        'Below roughly 40% of the height the load is comfortably low. Between '
        '40% and 60% is normal for a shelf in ordinary use. Past 70% the plan is '
        'treated as genuinely unsound, because at that point the unit relies on '
        'nothing bumping it.',
      ),
      GuideHeading('How to fix a top-heavy plan'),
      GuidePoints([
        'Move the single heaviest item down first. One large change beats several small ones.',
        'Keep the bottom level full rather than tidy. Space there is wasted stability.',
        'Put rarely used heavy items at the bottom, not out of the way at the top.',
        'Light and bulky belongs high: it takes room without raising the centre of mass much.',
      ]),
      GuideText(
        'Weight concentrated on one level is worth spreading too. A level holding '
        'more than 60% of everything puts all the strain on one board, even when '
        'the overall balance looks fine.',
      ),
    ],
  );

  static const GuideArticle capacity = GuideArticle(
    id: 'capacity',
    title: 'What shelf capacity really means',
    summary: 'How to set a sensible limit per level, and why the number is a guide.',
    readMinutes: 2,
    blocks: [
      GuideText(
        'Each level in a plan carries an assumed capacity in kilograms. The app '
        'starts from the width and type of the structure, because a wide board '
        'sags more than a narrow one under the same load.',
      ),
      GuideHeading('Set it from what you know'),
      GuideText(
        'If the unit came with a stated load rating, use it. Manufacturers quote '
        'a figure per shelf, and it is almost always lower than people assume. '
        'Where nothing is stated, judge by material and span.',
      ),
      GuidePoints([
        'Solid wood or steel, short span: the default is usually conservative.',
        'Particle board or a wide unsupported span: lower it, often by half.',
        'Glass: use the maker figure only. Do not estimate.',
        'A board that already bows visibly is past its limit whatever the label says.',
      ]),
      GuideHeading('Leave room to spare'),
      GuideText(
        'Loading a level to exactly its limit leaves nothing for the day someone '
        'leans on it or adds one more jar. Treating the capacity as a ceiling to '
        'stay under, rather than a target to reach, is what keeps a plan honest '
        'over time.',
      ),
      GuideFigure(
        value: '130%',
        caption:
            'Past this fraction of the level capacity the app stops calling it a '
            'caution and calls it unsound.',
      ),
      GuideText(
        'Capacity is also why fragile items are flagged on loaded levels. A board '
        'near its limit flexes, and flex is what breaks glass long before the '
        'shelf itself fails.',
      ),
    ],
  );

  static const GuideArticle fragile = GuideArticle(
    id: 'fragile',
    title: 'Protecting fragile items',
    summary: 'Where breakable things actually survive, and the mistake that breaks them.',
    readMinutes: 2,
    blocks: [
      GuideText(
        'Most breakages in storage are not dropped items. They are items crushed '
        'slowly by something heavier stored above or beside them, or cracked by a '
        'shelf that flexes under a load elsewhere on the same board.',
      ),
      GuideHeading('The rule that matters'),
      GuideText(
        'Nothing heavy directly above anything fragile. The app checks this on '
        'every plan and flags it, because it is both the most common mistake and '
        'the easiest to fix by swapping two items.',
      ),
      GuideFigure(
        value: '4x',
        caption:
            'An item this many times the weight of the fragile one below it '
            'counts as heavy for this check.',
      ),
      GuideHeading('Placing breakables well'),
      GuidePoints([
        'Give fragile items a level with capacity to spare, so the board does not flex.',
        'Keep them off the very top, where they are handled blind and knocked easily.',
        'Chest height is ideal: you can see what you are reaching for.',
        'Tall narrow items such as bottles need clearance above, not just floor space.',
        'Do not wedge breakables together. Contact between two hard items is where chips start.',
      ]),
      GuideHeading('Delicate is not fragile'),
      GuideText(
        'A cardboard box is delicate: it will sag and deform under load but it '
        'will not shatter. Glass is fragile. The distinction matters because a '
        'delicate item under moderate weight is worth a warning, while a fragile '
        'one under the same weight is a problem to fix now.',
      ),
    ],
  );

  static const GuideArticle balance = GuideArticle(
    id: 'balance',
    title: 'Reading the analysis',
    summary: 'What each figure on the analysis screen is telling you.',
    readMinutes: 3,
    blocks: [
      GuideText(
        'The analysis reduces a plan to a handful of figures. Each one answers a '
        'different question, and knowing which is which makes the warnings far '
        'easier to act on.',
      ),
      GuideHeading('Centre of mass: height'),
      GuideText(
        'How high up the combined weight sits, as a fraction of the total height. '
        'Lower is better. This is the figure that decides whether a plan reads as '
        'top-heavy.',
      ),
      GuideHeading('Centre of mass: sideways'),
      GuideText(
        'How far the weight sits from the middle, left or right. A unit loaded '
        'heavily on one side pulls in that direction, which matters most when the '
        'weight is also high up. The two combine into a tipping figure, which is '
        'why moving one item sideways can clear a warning that moving it down '
        'would also have cleared.',
      ),
      GuideFigure(
        value: '22%',
        caption: 'Sideways lean past this point is flagged as worth balancing.',
      ),
      GuideHeading('Weight distribution'),
      GuideText(
        'The share each level carries. Two plans can share a centre of mass and '
        'still differ: weight spread evenly across four levels behaves quite '
        'differently from the same weight stacked on one.',
      ),
      GuideHeading('Upper half share'),
      GuideText(
        'The fraction of the weight above the midpoint. A quick sanity check on '
        'the height figure, and often the clearer of the two when a plan has many '
        'levels.',
      ),
      GuideHeading('What the status means'),
      GuidePoints([
        'Stable: nothing found that is worth changing.',
        'Caution: sound as planned, but one or two things would make it better.',
        'Unsound: at least one finding serious enough to fix before loading it for real.',
      ]),
      GuideText(
        'All of it is an estimate from the figures entered. It assumes a frame in '
        'good condition on a level floor, and it cannot see a wobbly joint or a '
        'shelf already sagging. Trust it as a second pair of eyes, not as a '
        'certificate.',
      ),
    ],
  );

  static const GuideArticle measuring = GuideArticle(
    id: 'measuring',
    title: 'Measuring a space properly',
    summary: 'Getting the numbers right, since everything else depends on them.',
    readMinutes: 2,
    blocks: [
      GuideText(
        'The analysis is only as good as the measurements behind it. Three '
        'figures per structure and three per object are enough, provided they are '
        'taken consistently.',
      ),
      GuideHeading('The structure'),
      GuidePoints([
        'Width: the usable span between the uprights, not the outside of the frame.',
        'Depth: front to back of the usable shelf, ignoring any lip or rail.',
        'Height: floor to the top of the highest usable level.',
      ]),
      GuideText(
        'Then set the clearance of each level: the vertical gap between one board '
        'and the one above it. Uneven clearances are normal and worth entering '
        'accurately, because clearance is what decides whether a tall item fits.',
      ),
      GuideHeading('The objects'),
      GuideText(
        'Measure objects as they will stand. A book laid flat and a book stood '
        'upright have the same dimensions in different places, and only the '
        'standing orientation predicts what will fit.',
      ),
      GuidePoints([
        'Weigh containers as they will be stored, filled rather than empty.',
        'Round up rather than down. A tight fit on paper is no fit in practice.',
        'Include lids, handles and feet in the height.',
      ]),
      GuideHeading('Leave a margin'),
      GuideText(
        'A level filled to exactly its width leaves no room to get a hand in. '
        'Planning to somewhere near 90% of the span keeps things reachable, and '
        'reachable storage is the kind that stays tidy.',
      ),
    ],
  );

  /// Reading order: the ideas build on each other.
  static const List<GuideArticle> all = [
    weightLow,
    capacity,
    fragile,
    balance,
    measuring,
  ];

  static GuideArticle? byId(String id) {
    for (final GuideArticle article in all) {
      if (article.id == id) return article;
    }
    return null;
  }
}
