/* an enum named ahead of its definition (the x86 kernel's apic.h): gcc lays it unsigned int,
 * so the redeclaration agrees. a short-enum target cannot know the width yet, and refuses. held to gcc. */

extern enum mode later;
enum mode { M0, M1, M2 };
enum mode later = M2;

int main(void) {
  return (int)(later + 10 * sizeof later);   /* 42 */
}
