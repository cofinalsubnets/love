double am_sin(double), am_cos(double), am_atan2(double,double), am_sqrt(double), am_exp(double), am_log(double), am_pow(double,double);
static volatile double one = 1.0, two = 2.0, three = 3.0, half52 = 2.5, big = 1e9, neg = -20.5;
int run(void){
 int ok = 0;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 CK(am_sin(one) == 0.8414709848078965);          /* bit-identical to the host am floor */
 CK(am_cos(two) == -0.41614683654714241);
 CK(am_sqrt(two) == 1.4142135623730951);
 CK(am_exp(one) == 2.7182818284590455);
 CK(am_log(two) == 0.69314718055994529);
 CK(am_pow(three, half52) == 15.588457268119896);
 CK(am_atan2(one, two) == 0.46364760900080609);
 CK(am_sin(big) == 0.54584344944869956);         /* the big-argument reduction (rbig, d2ll) */
 CK(am_exp(neg) == 1.2501528663867428e-09);
 return 9;
}
