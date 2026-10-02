double lm_sin(double), lm_cos(double), lm_atan2(double,double), lm_sqrt(double), lm_exp(double), lm_log(double), lm_pow(double,double);
static volatile double one = 1.0, two = 2.0, three = 3.0, half52 = 2.5, big = 1e9, neg = -20.5;
int run(void){
 int ok = 0;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 CK(lm_sin(one) == 0.8414709848078965);          /* bit-identical to the host lm floor */
 CK(lm_cos(two) == -0.41614683654714241);
 CK(lm_sqrt(two) == 1.4142135623730951);
 CK(lm_exp(one) == 2.7182818284590455);
 CK(lm_log(two) == 0.69314718055994529);
 CK(lm_pow(three, half52) == 15.588457268119896);
 CK(lm_atan2(one, two) == 0.46364760900080609);
 CK(lm_sin(big) == 0.54584344944869956);         /* the big-argument reduction (rbig, d2ll) */
 CK(lm_exp(neg) == 1.2501528663867428e-09);
 return 9;
}
