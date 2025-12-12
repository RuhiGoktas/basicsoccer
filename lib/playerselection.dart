import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main.dart';

class Player {
  final String name;
  final int number;
  const Player({required this.name, required this.number});
}

class PlayerSelectionPage extends StatefulWidget {
  final String teamName; // e.g. "Turkey"
  const PlayerSelectionPage({super.key, required this.teamName});

  @override
  State<PlayerSelectionPage> createState() => _PlayerSelectionPageState();
}

class _PlayerSelectionPageState extends State<PlayerSelectionPage> {
  Player? selected;

List<Player> _playersForCountry(String country) {
  final c = _normalizeCountry(country);

  // DEBUG: print what you are actually receiving
  debugPrint("teamName raw='$country' normalized='$c'");

  switch (c) {
    case "mexico":
      return const [Player(name: "Lozano", number: 22), Player(name: "Gimenez", number: 9), Player(name: "Vega", number: 10)];

    case "south africa":
      return const [Player(name: "Tau", number: 11), Player(name: "Zwane", number: 18), Player(name: "Mothiba", number: 9)];

    case "ireland":
      return const [Player(name: "Ferguson", number: 9), Player(name: "Ogbene", number: 20), Player(name: "Idah", number: 10)];

    case "south korea":
    case "korea republic":
      return const [Player(name: "Son", number: 7), Player(name: "Hwang", number: 11), Player(name: "Lee", number: 10)];

    case "canada":
      return const [Player(name: "Davies", number: 19), Player(name: "David", number: 10), Player(name: "Larin", number: 9)];

    case "italy":
      return const [Player(name: "Chiesa", number: 7), Player(name: "Immobile", number: 9), Player(name: "Raspadori", number: 10)];

    case "qatar":
      return const [Player(name: "Afif", number: 10), Player(name: "Ali", number: 19), Player(name: "Hassan", number: 11)];

    case "switzerland":
      return const [Player(name: "Shaqiri", number: 23), Player(name: "Embolo", number: 7), Player(name: "Amdouni", number: 9)];

    case "brazil":
      return const [Player(name: "Neymar", number: 10), Player(name: "Vinicius", number: 7), Player(name: "Rodrygo", number: 11)];

    case "morocco":
      return const [Player(name: "Ziyech", number: 7), Player(name: "EnNesyri", number: 19), Player(name: "Boufal", number: 17)];

    case "haiti":
      return const [Player(name: "Nazon", number: 9), Player(name: "Pierrot", number: 20), Player(name: "Etienne", number: 7)];

    case "scotland":
      return const [Player(name: "McTominay", number: 4), Player(name: "Adams", number: 10), Player(name: "Christie", number: 11)];

    case "usa":
    case "united states":
      return const [Player(name: "Pulisic", number: 10), Player(name: "Weah", number: 21), Player(name: "Balogun", number: 9)];

    case "paraguay":
      return const [Player(name: "Almiron", number: 10), Player(name: "Enciso", number: 19), Player(name: "Sanabria", number: 9)];

    case "turkey":
      return const [Player(name: "Hakan", number: 10), Player(name: "Kenan", number: 11), Player(name: "Arda", number: 8)];

    case "australia":
      return const [Player(name: "Leckie", number: 7), Player(name: "Goodwin", number: 11), Player(name: "Duke", number: 9)];

    case "germany":
      return const [Player(name: "Musiala", number: 10), Player(name: "Havertz", number: 7), Player(name: "Wirtz", number: 17)];

    case "curacao": // normalized removes ç -> c
      return const [Player(name: "Bacuna", number: 7), Player(name: "Janga", number: 9), Player(name: "Antonisse", number: 11)];

    case "ivory coast":
    case "cote d'ivoire":
      return const [Player(name: "Haller", number: 22), Player(name: "Zaha", number: 10), Player(name: "Pepe", number: 19)];

    case "ecuador":
      return const [Player(name: "Valencia", number: 13), Player(name: "Plata", number: 19), Player(name: "Minda", number: 11)];

    case "netherlands":
      return const [Player(name: "Depay", number: 10), Player(name: "Gakpo", number: 11), Player(name: "Bergwijn", number: 7)];

    case "japan":
      return const [Player(name: "Kubo", number: 10), Player(name: "Mitoma", number: 7), Player(name: "Minamino", number: 8)];

    case "poland":
      return const [Player(name: "Lewandowski", number: 9), Player(name: "Zielinski", number: 10), Player(name: "Szymanski", number: 11)];

    case "tunisia":
      return const [Player(name: "Msakni", number: 10), Player(name: "Khazri", number: 7), Player(name: "Jaziri", number: 9)];

    case "belgium":
      return const [Player(name: "DeBruyne", number: 7), Player(name: "Lukaku", number: 9), Player(name: "Trossard", number: 11)];

    case "egypt":
      return const [Player(name: "Salah", number: 10), Player(name: "Trezeguet", number: 7), Player(name: "Mostafa", number: 11)];

    case "iran":
      return const [Player(name: "Taremi", number: 9), Player(name: "Azmoun", number: 20), Player(name: "Jahanbakhsh", number: 18)];

    case "new zealand":
      return const [Player(name: "Wood", number: 9), Player(name: "Singh", number: 11), Player(name: "Barbarouses", number: 7)];

    case "spain":
      return const [Player(name: "Morata", number: 7), Player(name: "Pedri", number: 8), Player(name: "Yamal", number: 19)];

    case "cape verde":
    case "cabo verde":
      return const [Player(name: "Monteiro", number: 10), Player(name: "Tavares", number: 7), Player(name: "Semedo", number: 9)];

    case "saudi arabia":
      return const [Player(name: "AlDawsari", number: 10), Player(name: "AlShehri", number: 9), Player(name: "Kanno", number: 23)];

    case "uruguay":
      return const [Player(name: "Nunez", number: 9), Player(name: "Valverde", number: 15), Player(name: "Arrascaeta", number: 10)];

    case "france":
      return const [Player(name: "Mbappe", number: 10), Player(name: "Griezmann", number: 7), Player(name: "Dembele", number: 11)];

    case "senegal":
      return const [Player(name: "Mane", number: 10), Player(name: "Dia", number: 9), Player(name: "Sarr", number: 18)];

    case "bolivia":
      return const [Player(name: "Moreno", number: 9), Player(name: "Vaca", number: 10), Player(name: "Saucedo", number: 7)];

    case "norway":
      return const [Player(name: "Haaland", number: 9), Player(name: "Odegaard", number: 10), Player(name: "Sorloth", number: 7)];

    case "argentina":
      return const [Player(name: "Messi", number: 10), Player(name: "Alvarez", number: 9), Player(name: "DiMaria", number: 11)];

    case "algeria":
      return const [Player(name: "Mahrez", number: 7), Player(name: "Slimani", number: 9), Player(name: "Bounedjah", number: 18)];

    case "austria":
      return const [Player(name: "Arnautovic", number: 7), Player(name: "Baumgartner", number: 14), Player(name: "Sabitzer", number: 9)];

    case "jordan":
      return const [Player(name: "AlTamari", number: 10), Player(name: "AlMardi", number: 11), Player(name: "Rawashdeh", number: 9)];

    case "portugal":
      return const [Player(name: "Ronaldo", number: 7), Player(name: "Bruno", number: 8), Player(name: "Leao", number: 10)];

    case "uzbekistan":
      return const [Player(name: "Shomurodov", number: 9), Player(name: "Masharipov", number: 10), Player(name: "Eldor", number: 11)];

    case "colombia":
      return const [Player(name: "LuisDiaz", number: 7), Player(name: "Borre", number: 19), Player(name: "James", number: 10)];

    case "england":
      return const [Player(name: "Kane", number: 9), Player(name: "Bellingham", number: 10), Player(name: "Saka", number: 7)];

    case "croatia":
      return const [Player(name: "Modric", number: 10), Player(name: "Kramaric", number: 9), Player(name: "Perisic", number: 14)];

    case "ghana":
      return const [Player(name: "Kudus", number: 10), Player(name: "Ayew", number: 9), Player(name: "Sulemana", number: 22)];

    case "panama":
      return const [Player(name: "Diaz", number: 7), Player(name: "Waterman", number: 9), Player(name: "Quintero", number: 10)];

    default:
      // IMPORTANT: do NOT hide mismatch bugs with "Player A"
      return const [Player(name: "UNKNOWN", number: 0)];
  }
}

  Color _skinColorForCountry(String country) {
  switch (country.toLowerCase()) {
    case "ghana":
    case "senegal":
    case "curaçao":
    case "south africa":
    case "france": // as you requested
      return const Color(0xFFC08A5A); // medium brown
    default:
      return const Color(0xFFF1C89A); // your current light tone
  }
}
String _normalizeCountry(String c) {
  return c
      .toLowerCase()
      .trim()
      .replaceAll("ç", "c")
      .replaceAll("ğ", "g")
      .replaceAll("ı", "i")
      .replaceAll("ö", "o")
      .replaceAll("ş", "s")
      .replaceAll("ü", "u")
      .replaceAll("é", "e")
      .replaceAll("á", "a")
      .replaceAll("ã", "a")
      .replaceAll("ô", "o")
      .replaceAll("ó", "o")
      .replaceAll("í", "i")
      .replaceAll("ú", "u");
}



  @override
  Widget build(BuildContext context) {
    final players = _playersForCountry(widget.teamName);
    final isTurkey = widget.teamName.toLowerCase() == "turkey";
	final kitColor = _kitColorForCountry(widget.teamName);
	final skinColor = _skinColorForCountry(widget.teamName);


    return Scaffold(
      backgroundColor: const Color(0xFF0D1B12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("${widget.teamName} — Pick Your Player"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeaderCard(
                title: "Choose your hero",
                subtitle: selected == null
                    ? "Tap a player card to select."
                    : "Selected: ${selected!.name} ✅",
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: players.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, i) {
                  final p = players[i];
                  final isSelected = selected?.name == p.name && selected?.number == p.number;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() => selected = p);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You picked "${p.name}"'),
                          duration: const Duration(milliseconds: 900),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12261A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? Colors.white.withOpacity(0.65) : Colors.white.withOpacity(0.10),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: isSelected ? 18 : 10,
                            spreadRadius: 0,
                            color: Colors.black.withOpacity(0.25),
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: CustomPaint(
                                painter: CartoonPlayerPainter(
                                  jerseyColor: kitColor, // turkey => red kit
                                  number: p.number,
                                  drawTurkeyFlag: isTurkey,
								  skinColor: skinColor,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "#${p.number}",
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              p.name,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
				onPressed: selected == null
					? null
					: () {
						Navigator.push(
						  context,
						  MaterialPageRoute(builder: (_) => const PenaltyStagePage()),
						);
					  },

                  child: Text(selected == null ? "Pick a player to continue" : "Continue as ${selected!.name}"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Color _kitColorForCountry(String country) {
  switch (country.toLowerCase()) {

    // ===== GROUP A =====
    case "mexico":
      return const Color(0xFF006847); // green
    case "south africa":
      return const Color(0xFF2E7D32); // green
    case "ireland":
      return const Color(0xFF2E7D32); // green
    case "korea republic":
    case "south korea":
      return const Color(0xFFE53935); // red

    // ===== GROUP B =====
    case "canada":
      return const Color(0xFFE53935); // red
    case "italy":
      return const Color(0xFF1565C0); // azzurri blue
    case "qatar":
      return const Color(0xFF6A1B4D); // maroon
    case "switzerland":
      return const Color(0xFFD32F2F); // red

    // ===== GROUP C =====
    case "brazil":
      return const Color(0xFFF9A825); // yellow
    case "morocco":
      return const Color(0xFFD32F2F); // red
    case "haiti":
      return const Color(0xFF1565C0); // blue
    case "scotland":
      return const Color(0xFF1E88E5); // blue

    // ===== GROUP D =====
    case "usa":
    case "united states":
      return const Color(0xFF0D47A1); // navy
    case "paraguay":
      return const Color(0xFFD32F2F); // red/white dominant
    case "turkey":
      return const Color(0xFFE53935); // red
    case "australia":
      return const Color(0xFFFBC02D); // gold

    // ===== GROUP E =====
    case "germany":
      return const Color(0xFF212121); // black
    case "curaçao":
    case "curacao":
      return const Color(0xFF1565C0); // blue
    case "cote d'ivoire":
    case "ivory coast":
      return const Color(0xFFEF6C00); // orange
    case "ecuador":
      return const Color(0xFFFDD835); // yellow

    // ===== GROUP F =====
    case "netherlands":
      return const Color(0xFFEF6C00); // orange
    case "japan":
      return const Color(0xFF0D47A1); // blue
    case "poland":
      return const Color(0xFFD32F2F); // red
    case "tunisia":
      return const Color(0xFFD32F2F); // red

    // ===== GROUP G =====
    case "belgium":
      return const Color(0xFFD32F2F); // red
    case "egypt":
      return const Color(0xFFD32F2F); // red
    case "iran":
      return const Color(0xFFD32F2F); // red
    case "new zealand":
      return const Color(0xFF212121); // black

    // ===== GROUP H =====
    case "spain":
      return const Color(0xFFC62828); // red
    case "cape verde":
    case "cabo verde":
      return const Color(0xFF0D47A1); // blue
    case "saudi arabia":
      return const Color(0xFF1B5E20); // green
    case "uruguay":
      return const Color(0xFF42A5F5); // sky blue

    // ===== GROUP I =====
    case "france":
      return const Color(0xFF1E3A8A); // deep blue
    case "senegal":
      return const Color(0xFF2E7D32); // green
    case "bolivia":
      return const Color(0xFF2E7D32); // green
    case "norway":
      return const Color(0xFFD32F2F); // red

    // ===== GROUP J =====
    case "argentina":
      return const Color(0xFF4FC3F7); // light blue
    case "algeria":
      return const Color(0xFF2E7D32); // green
    case "austria":
      return const Color(0xFFD32F2F); // red
    case "jordan":
      return const Color(0xFF212121); // black

    // ===== GROUP K =====
    case "portugal":
      return const Color(0xFFB71C1C); // deep red
    case "uzbekistan":
      return const Color(0xFF1E88E5); // blue
    case "colombia":
      return const Color(0xFFFDD835); // yellow

    // ===== GROUP L =====
    case "england":
      return const Color(0xFFF5F5F5); // white
    case "croatia":
      return const Color(0xFFD32F2F); // red
    case "ghana":
      return const Color(0xFFD32F2F); // red
    case "panama":
      return const Color(0xFFD32F2F); // red

    // ===== FALLBACK =====
    default:
      return const Color(0xFFF5F5F5);
  }
}


  }

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12261A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class CartoonPlayerPainter extends CustomPainter {
  final Color jerseyColor;
  final int number;
  final bool drawTurkeyFlag;
  final Color skinColor;

  CartoonPlayerPainter({
    required this.jerseyColor,
    required this.number,
    required this.drawTurkeyFlag,
	required this.skinColor,
  });

@override
void paint(Canvas canvas, Size size) {
  final paint = Paint()..isAntiAlias = true;

  final w = size.width;
  final h = size.height;

  // Background card
  paint.color = Colors.white.withOpacity(0.04);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
    paint,
  );

  // Head position/size (same as you used)
  final headCenter = Offset(w * 0.5, h * 0.28);
  final headR = (w < h ? w : h) * 0.18;

  // ---- 1) NECK (draw FIRST so head sits on top) ----
  final neckW = headR * 0.95;
  final neckH = headR * 0.55;
  final neckTopY = headCenter.dy + headR * 0.85;

  paint.color = skinColor.withOpacity(0.98);
  final neck = RRect.fromRectAndRadius(
    Rect.fromLTWH(headCenter.dx - neckW / 2, neckTopY, neckW, neckH),
    Radius.circular(neckH * 0.35),
  );
  canvas.drawRRect(neck, paint);

  // ---- 2) BODY / JERSEY ----
  final jerseyTop = neckTopY + neckH * 0.35;
  final jerseyW = w * 0.70;
  final jerseyH = h * 0.52;

  paint.color = jerseyColor;
  final jersey = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(headCenter.dx, jerseyTop + jerseyH * 0.50),
      width: jerseyW,
      height: jerseyH,
    ),
    Radius.circular(w * 0.10),
  );
  canvas.drawRRect(jersey, paint);

  // Collar (small V)
  paint.color = Colors.white.withOpacity(0.85);
  final collar = Path()
    ..moveTo(headCenter.dx - jerseyW * 0.12, jerseyTop + jerseyH * 0.06)
    ..lineTo(headCenter.dx, jerseyTop + jerseyH * 0.14)
    ..lineTo(headCenter.dx + jerseyW * 0.12, jerseyTop + jerseyH * 0.06)
    ..close();
  canvas.drawPath(collar, paint);

  // ---- 3) ARMS (thicker, more natural) ----
  paint.color = skinColor.withOpacity(0.98);

  // Left arm
  final leftArm = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      headCenter.dx - jerseyW * 0.62,
      jerseyTop + jerseyH * 0.18,
      jerseyW * 0.28,
      jerseyH * 0.22,
    ),
    Radius.circular(jerseyH * 0.10),
  );
  canvas.drawRRect(leftArm, paint);

  // Right arm
  final rightArm = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      headCenter.dx + jerseyW * 0.34,
      jerseyTop + jerseyH * 0.18,
      jerseyW * 0.28,
      jerseyH * 0.22,
    ),
    Radius.circular(jerseyH * 0.10),
  );
  canvas.drawRRect(rightArm, paint);

  // Sleeves (overlay to blend arms into jersey)
  paint.color = jerseyColor.withOpacity(0.95);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        headCenter.dx - jerseyW * 0.46,
        jerseyTop + jerseyH * 0.16,
        jerseyW * 0.12,
        jerseyH * 0.12,
      ),
      Radius.circular(jerseyH * 0.08),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        headCenter.dx + jerseyW * 0.34,
        jerseyTop + jerseyH * 0.16,
        jerseyW * 0.12,
        jerseyH * 0.12,
      ),
      Radius.circular(jerseyH * 0.08),
    ),
    paint,
  );

  // ---- 4) NUMBER ----
  final tp = TextPainter(
    text: TextSpan(
      text: "$number",
      style: TextStyle(
        color: Colors.white.withOpacity(0.95),
        fontSize: w * 0.20,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(headCenter.dx - tp.width / 2, jerseyTop + jerseyH * 0.32));

  // ---- 5) TURKEY BADGE (optional) ----
  if (drawTurkeyFlag) {
    _drawTurkeyBadge(
      canvas,
      Offset(headCenter.dx - jerseyW * 0.30, jerseyTop + jerseyH * 0.18),
      w * 0.16,
      w * 0.11,
    );
  }

  // ---- 6) FACE (draw LAST so it sits above neck) ----
  _drawRealisticFace(canvas, size, headCenter, headR);
}


void _drawRealisticFace(Canvas canvas, Size size, Offset headCenter, double headR) {
  final paint = Paint()..isAntiAlias = true;

  // --- FACE SHAPE ---
  final faceRect = Rect.fromCenter(
    center: headCenter,
    width: headR * 2.05,
    height: headR * 2.35,
  );
  final faceRRect = RRect.fromRectAndRadius(faceRect, Radius.circular(headR * 0.95));
  final facePath = Path()..addRRect(faceRRect);

  // Base skin
  paint.color = skinColor;
  canvas.drawRRect(faceRRect, paint);

  // --- SHADING (CLIPPED TO FACE, so nothing becomes "hair blobs") ---
  canvas.save();
  canvas.clipPath(facePath);

  // Cheek + chin shading (kept low)
  paint.color = Colors.black.withOpacity(0.07);
  canvas.drawCircle(Offset(headCenter.dx - headR * 0.50, headCenter.dy + headR * 0.45), headR * 0.48, paint);
  canvas.drawCircle(Offset(headCenter.dx + headR * 0.50, headCenter.dy + headR * 0.45), headR * 0.48, paint);
  canvas.drawCircle(Offset(headCenter.dx, headCenter.dy + headR * 0.95), headR * 0.60, paint);

  // Small forehead highlight (NOT a huge circle)
  paint.color = Colors.white.withOpacity(0.06);
  canvas.drawCircle(Offset(headCenter.dx - headR * 0.18, headCenter.dy - headR * 0.60), headR * 0.28, paint);

  canvas.restore();

  // --- EARS ---
  paint.color = skinColor.withOpacity(0.98);
  final earW = headR * 0.42;
  final earH = headR * 0.62;

  final leftEar = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(headCenter.dx - headR * 1.02, headCenter.dy + headR * 0.02),
      width: earW,
      height: earH,
    ),
    Radius.circular(earW * 0.5),
  );
  final rightEar = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(headCenter.dx + headR * 1.02, headCenter.dy + headR * 0.02),
      width: earW,
      height: earH,
    ),
    Radius.circular(earW * 0.5),
  );
  canvas.drawRRect(leftEar, paint);
  canvas.drawRRect(rightEar, paint);

  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = headR * 0.05
    ..color = Colors.black.withOpacity(0.12)
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(
    Rect.fromCenter(center: Offset(headCenter.dx - headR * 1.02, headCenter.dy + headR * 0.06), width: earW * 0.7, height: earH * 0.7),
    0.2,
    2.4,
    false,
    paint,
  );
  canvas.drawArc(
    Rect.fromCenter(center: Offset(headCenter.dx + headR * 1.02, headCenter.dy + headR * 0.06), width: earW * 0.7, height: earH * 0.7),
    0.6,
    2.4,
    false,
    paint,
  );
  paint.style = PaintingStyle.fill;

  // =====================
  // HAIR: NORMAL SHORT MALE (ONE PATH ONLY)
  // No clipRect, no oval, no shine => no half-circle artifacts.
  // =====================
  final hairPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF2A1A10);

  final hairlineY = headCenter.dy - headR * 0.68;
  final leftX = headCenter.dx - headR * 0.98;
  final rightX = headCenter.dx + headR * 0.98;
  final topY = headCenter.dy - headR * 1.12;

  final hairPath = Path()
    ..moveTo(leftX, hairlineY)
    ..quadraticBezierTo(headCenter.dx - headR * 0.85, topY, headCenter.dx, topY)
    ..quadraticBezierTo(headCenter.dx + headR * 0.85, topY, rightX, hairlineY)
    ..quadraticBezierTo(headCenter.dx, hairlineY + headR * 0.08, leftX, hairlineY)
    ..close();

  canvas.drawPath(hairPath, hairPaint);

  // --- EYES (simple, clean) ---
  void eye(Offset c) {
    paint.color = const Color(0xFFF4F6F8);
    final eyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: headR * 0.62, height: headR * 0.30),
      Radius.circular(headR * 0.18),
    );
    canvas.drawRRect(eyeRect, paint);

    paint.color = const Color(0xFF4E342E);
    canvas.drawCircle(Offset(c.dx, c.dy + headR * 0.01), headR * 0.10, paint);

    paint.color = const Color(0xFF0B0B0B);
    canvas.drawCircle(Offset(c.dx, c.dy + headR * 0.01), headR * 0.05, paint);

    paint.color = Colors.white.withOpacity(0.95);
    canvas.drawCircle(Offset(c.dx + headR * 0.03, c.dy - headR * 0.02), headR * 0.02, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.05
      ..color = Colors.black.withOpacity(0.30)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: c, width: headR * 0.66, height: headR * 0.34),
      math.pi,
      math.pi,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
  }

  eye(Offset(headCenter.dx - headR * 0.45, headCenter.dy - headR * 0.02));
  eye(Offset(headCenter.dx + headR * 0.45, headCenter.dy - headR * 0.02));

  // --- NOSE ---
  paint.color = Colors.black.withOpacity(0.10);
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = headR * 0.06
    ..strokeCap = StrokeCap.round;

  final nosePath = Path()
    ..moveTo(headCenter.dx, headCenter.dy - headR * 0.02)
    ..quadraticBezierTo(
      headCenter.dx - headR * 0.05,
      headCenter.dy + headR * 0.25,
      headCenter.dx + headR * 0.02,
      headCenter.dy + headR * 0.40,
    );
  canvas.drawPath(nosePath, paint);

  paint.style = PaintingStyle.fill;
  paint.color = Colors.black.withOpacity(0.12);
  canvas.drawCircle(Offset(headCenter.dx - headR * 0.08, headCenter.dy + headR * 0.44), headR * 0.03, paint);
  canvas.drawCircle(Offset(headCenter.dx + headR * 0.08, headCenter.dy + headR * 0.44), headR * 0.03, paint);

  // --- MOUTH ---
  final mouthC = Offset(headCenter.dx, headCenter.dy + headR * 0.62);
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = headR * 0.06
    ..color = Colors.black.withOpacity(0.22)
    ..strokeCap = StrokeCap.round;

  canvas.drawArc(
    Rect.fromCenter(center: Offset(mouthC.dx, mouthC.dy - headR * 0.02), width: headR * 0.70, height: headR * 0.28),
    0.1,
    math.pi - 0.2,
    false,
    paint,
  );

  paint
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFD28D7F).withOpacity(0.50);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(mouthC.dx, mouthC.dy + headR * 0.05), width: headR * 0.55, height: headR * 0.16),
      Radius.circular(headR * 0.10),
    ),
    paint,
  );
}

  void _drawTurkeyBadge(Canvas canvas, Offset topLeft, double bw, double bh) {
    final paint = Paint()..isAntiAlias = true;

    // Red badge
    paint.color = const Color(0xFFD32F2F);
    final badge = RRect.fromRectAndRadius(Rect.fromLTWH(topLeft.dx, topLeft.dy, bw, bh), Radius.circular(bh * 0.22));
    canvas.drawRRect(badge, paint);

    // Crescent (two circles)
    paint.color = Colors.white;
    final c1 = Offset(topLeft.dx + bw * 0.42, topLeft.dy + bh * 0.52);
    final r1 = bh * 0.26;
    canvas.drawCircle(c1, r1, paint);

    paint.color = const Color(0xFFD32F2F);
    final c2 = Offset(topLeft.dx + bw * 0.48, topLeft.dy + bh * 0.52);
    final r2 = bh * 0.21;
    canvas.drawCircle(c2, r2, paint);

    // Star (simple 5-point)
    paint.color = Colors.white;
    final starCenter = Offset(topLeft.dx + bw * 0.68, topLeft.dy + bh * 0.52);
    final starR = bh * 0.16;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 5);
      final r = (i % 2 == 0) ? starR : starR * 0.45;
      final p = Offset(starCenter.dx + r * math.cos(angle), starCenter.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CartoonPlayerPainter oldDelegate) {
    return oldDelegate.jerseyColor  != jerseyColor  ||
        oldDelegate.number != number ||
        oldDelegate.drawTurkeyFlag != drawTurkeyFlag;
  }
}
