keywords = ["and","as","band","bnot","bor","break","bxor","case","class","const","continue","each","else","end","false","for","foreach","from","fun","if","import","in","item","let","nil","or","print","pub","return","self","shl","shr","super","switch","true","var","while"]

def test_mults(m1, m2, m3, m4):
    seen = set()
    for s in keywords:
        if len(s) == 0: return False
        first = ord(s[0])
        last = ord(s[-1])
        middle = ord(s[len(s) // 2]) if len(s) > 2 else first
        h = (first * m1) + (last * m2) + (middle * m3) + (len(s) * m4)
        h = h & 255
        if h in seen:
            return False
        seen.add(h)
    return True

for m1 in range(1, 100):
    for m2 in range(1, 100):
        for m3 in range(1, 100):
            for m4 in range(1, 100):
                if test_mults(m1, m2, m3, m4):
                    print(f"FOUND: HASH_MULT_FIRST = {m1}, HASH_MULT_LAST = {m2}, HASH_MULT_MID = {m3}, HASH_MULT_LEN = {m4}")
                    exit(0)
