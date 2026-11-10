; ================================================================
; Slate - estilos compartilhados (padrao QuantoFlx: 256px, Cr=8, Sp=2)
; IMPORTANTE: estilos saem em 1 nivel (sem MeterStyle aninhado) porque
; o Rainmeter NAO encadeia MeterStyle recursivamente!
; Performance: DynamicVariables=1 NAO fica no estilo global - e
; declarado apenas nos meters que realmente usam [Measure] em Text/X/Shape.
; ================================================================

; --- Tipografia plana (todos os estilos tem AntiAlias=1 direto) ---
[TextStyle]
FontFace=#FontMedium#
FontSize=9
FontColor=#TextPrimary#
AntiAlias=1

[BoldStyle]
FontFace=#FontBold#
FontSize=10
FontColor=#TextPrimary#
AntiAlias=1

[SecondaryStyle]
FontFace=#FontMain#
FontSize=9
FontColor=#TextSecondary#
AntiAlias=1

[FaintStyle]
FontFace=#FontMain#
FontSize=9
FontColor=#TextFaint#
AntiAlias=1

[RightPrimaryStyle]
FontFace=#FontMono#
FontSize=9
FontColor=#TextPrimary#
StringAlign=RightTop
AntiAlias=1

[RightSecondaryStyle]
FontFace=#FontMono#
FontSize=9
FontColor=#TextSecondary#
StringAlign=RightTop
AntiAlias=1

[GraphTitleStyle]
FontFace=#FontMedium#
FontSize=8
FontColor=#AccentColor#,255
StringAlign=LeftBottom
ClipString=1
AntiAlias=1

[GraphPeakStyle]
FontFace=#FontMono#
FontSize=8
FontColor=#TextFaint#
StringAlign=RightTop
ClipString=1
AntiAlias=1

; --- Icones 32x32 no header ---
[HeaderIconStyle]
ImageTint=242,245,250,255
W=32
H=32
X=16
Y=12
AntiAlias=1

; --- Containers de Card (4x1 = 256x64, 4x2 = 256x128, 4x4 = 256x256) ---
[Card4x1Style]
Shape=Rectangle 2,2,252,60,6,6 | StrokeWidth 1 | Stroke Color #CardStroke# | Fill Color #CardColor#
Shape2=Line 8,2,248,2 | StrokeWidth 1 | Stroke Color #CardBevel#

[Card4x2Style]
Shape=Rectangle 2,2,252,124,6,6 | StrokeWidth 1 | Stroke Color #CardStroke# | Fill Color #CardColor#
Shape2=Line 8,2,248,2 | StrokeWidth 1 | Stroke Color #CardBevel#

[Card4x4Style]
Shape=Rectangle 2,2,252,256,6,6 | StrokeWidth 1 | Stroke Color #CardStroke# | Fill Color #CardColor#
Shape2=Line 8,2,248,2 | StrokeWidth 1 | Stroke Color #CardBevel#
