
The following assertion was thrown during layout:
A RenderFlex overflowed by 14 pixels on the bottom.

The relevant error-causing widget was:
    Column Column:file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/features/home/home_screen.dart:588:16

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be seen. If the content is legitimately bigger than the available space, consider clipping it with a ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex, like a ListView.


The specific RenderFlex in question is: RenderFlex#88343 OVERFLOWING
    parentData: offset=Offset(17.0, 17.0) (can use size)
    constraints: BoxConstraints(w=132.0, h=84.6)
    size: Size(132.0, 84.6)
    direction: vertical
    mainAxisAlignment: start
    mainAxisSize: max
    crossAxisAlignment: start
    textDirection: ltr
    verticalDirection: down
    spacing: 0.0
    child 1: RenderConstrainedBox#b36ce relayoutBoundary=up1
        parentData: offset=Offset(0.0, 0.0); flex=null; fit=null (can use size)
        constraints: BoxConstraints(0.0<=w<=132.0, 0.0<=h<=Infinity)
        size: Size(40.0, 40.0)
        additionalConstraints: BoxConstraints(w=40.0, h=40.0)
        child: RenderDecoratedBox#ef248
            parentData: <none> (can use size)
            constraints: BoxConstraints(w=40.0, h=40.0)
            size: Size(40.0, 40.0)
            decoration: BoxDecoration
                color: Color(alpha: 0.1500, red: 0.0235, green: 0.7137, blue: 0.8314, colorSpace: ColorSpace.sRGB)
                borderRadius: BorderRadius.circular(12.0)
            configuration: ImageConfiguration(bundle: PlatformAssetBundle#eafb6(), devicePixelRatio: 2.8, locale: vi, textDirection: TextDirection.ltr, platform: android)
            child: RenderPadding#b82d6
                parentData: <none> (can use size)
                constraints: BoxConstraints(w=40.0, h=40.0)
                size: Size(40.0, 40.0)
                padding: EdgeInsets.zero
                textDirection: ltr
                child: RenderSemanticsAnnotations#6e52b
                    parentData: offset=Offset(0.0, 0.0) (can use size)
                    constraints: BoxConstraints(w=40.0, h=40.0)
                    size: Size(40.0, 40.0)
    child 2: RenderConstrainedBox#05fcd relayoutBoundary=up1
        parentData: offset=Offset(0.0, 40.0); flex=1; fit=FlexFit.tight (can use size)
        constraints: BoxConstraints(0.0<=w<=132.0, h=0.0)
        size: Size(0.0, 0.0)
        additionalConstraints: BoxConstraints(w=0.0, h=0.0)
    child 3: RenderParagraph#3931c relayoutBoundary=up1
        parentData: offset=Offset(0.0, 40.0); flex=null; fit=null (can use size)
        constraints: BoxConstraints(0.0<=w<=132.0, 0.0<=h<=Infinity)
        size: Size(132.0, 40.0)
        textAlign: start
        textDirection: ltr
        softWrap: wrapping at box width
        overflow: clip
        locale: vi
        maxLines: unlimited
        text: TextSpan
            debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown)
            inherit: false
            color: Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB)
            family: Roboto
            size: 14.0
            weight: 700
            letterSpacing: 0.3
            baseline: alphabetic
            height: 1.4x
            leadingDistribution: even
            decoration: Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB) TextDecoration.none
            "Australian Accountant"
    child 4: RenderConstrainedBox#27dbd relayoutBoundary=up1
        parentData: offset=Offset(0.0, 80.0); flex=null; fit=null (can use size)
        constraints: BoxConstraints(0.0<=w<=132.0, 0.0<=h<=Infinity)
        size: Size(0.0, 2.0)
        additionalConstraints: BoxConstraints(0.0<=w<=Infinity, h=2.0)
    child 5: RenderParagraph#4b7ea relayoutBoundary=up1
        parentData: offset=Offset(0.0, 82.0); flex=null; fit=null (can use size)
        constraints: BoxConstraints(0.0<=w<=132.0, 0.0<=h<=Infinity)
        size: Size(43.7, 17.0)
        textAlign: start
        textDirection: ltr
        softWrap: wrapping at box width
        overflow: clip
        locale: vi
        maxLines: unlimited
        text: TextSpan
            debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown)
            inherit: false
            color: Color(alpha: 0.3843, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB)
            family: Roboto
            size: 12.0
            weight: 400
            letterSpacing: 0.3
            baseline: alphabetic
            height: 1.4x
            leadingDistribution: even
            decoration: Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB) TextDecoration.none
            "Finance"