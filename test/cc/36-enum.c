enum color { RED, GREEN = 5, BLUE };
int main() { enum color c = BLUE; switch (c) { case RED: return 1; case GREEN: return 2; case BLUE: return RED + GREEN + BLUE + 31; } return 0; }
