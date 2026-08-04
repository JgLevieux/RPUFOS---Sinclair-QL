import math

TABLE_SIZE = 1024
MAX_VAL = 31

raw_values = []

# 1. Génération de la courbe brute
for i in range(TABLE_SIZE):
    t = (i / TABLE_SIZE) * 2 * math.pi
    
    # Utilisation EXCLUSIVE de sinus purs (sans déphasage).
    # sin(0) = 0, ce qui garantit le démarrage et le bouclage parfait sur zéro.
    val = (
        1.0 * math.sin(t) + 
        0.6 * math.sin(2 * t) + 
        0.3 * math.sin(3 * t) + 
        0.2 * math.sin(5 * t)
    )
    raw_values.append(val)

# 2. Recherche de l'amplitude maximale pour conserver le zéro au centre
min_v = min(raw_values)
max_v = max(raw_values)
peak = max(abs(min_v), abs(max_v))

print("deform_table:")
for i in range(0, TABLE_SIZE, 16): 
    line_vals = []
    for j in range(16):
        if i + j < TABLE_SIZE:
            v = raw_values[i + j]
            
            # Normalisation centrée (v / peak donne une valeur de -1.0 à +1.0)
            norm = v / peak
            
            final_val = int(round(norm * MAX_VAL))
            final_val = max(-63, min(63, final_val))
            line_vals.append(str(final_val))
            
    print(f"\tDC.B {','.join(line_vals)}")