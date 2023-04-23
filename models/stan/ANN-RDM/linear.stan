// ANN-RDM with linear mapping function for drifts,
// different threshold for words and nonwords,
// without non-decision time modulation

functions {
    real race_pdf(real t, real b, real v){
        real pdf;
        pdf = b/sqrt(2 * pi() * pow(t, 3)) * exp(-pow(v*t-b, 2) / (2*t));
        return pdf;
    }

    real race_cdf(real t, real b, real v){
        real cdf;
        cdf = Phi((v*t-b)/sqrt(t)) + exp(2*v*b) * Phi(-(v*t+b)/sqrt(t));
        return cdf;
    }

    real race_lpdf(matrix RT, vector ndt, vector b_word, vector b_nonword, vector drift_word, vector drift_nonword){

        real t;
        vector[rows(RT)] prob;
        real cdf;
        real pdf;
        real out;

        for (i in 1:rows(RT)){
            t = RT[i,1] - ndt[i];
            if(t > 0){
                if(RT[i,2] == 1){
                    pdf = race_pdf(t, b_word[i], drift_word[i]);
                    cdf = 1 - race_cdf(t, b_nonword[i], drift_nonword[i]);
                }
                else{
                    pdf = race_pdf(t, b_nonword[i], drift_nonword[i]);
                    cdf = 1 - race_cdf(t, b_word[i], drift_word[i]);
                }
                prob[i] = pdf*cdf;

                if(prob[i] < 1e-10){
                    prob[i] = 1e-10;
                }
            }
        else{
                prob[i] = 1e-10;
            }
        }
        out = sum(log(prob));
        return out;
     }
}

data {
    int<lower=1> N;                                 // number of data items
    int<lower=1> L;                                 // number of levels
    int<lower=1, upper=L> participant[N];           // level (participant)

    vector[2] p[N];                                 // Semantic Word Probabilty p[n][1]:word probability p[n][2]:non-word probability
    int<lower=0> frequency[N];                      // zipf values (representing frequency)
    int<lower=0,upper=1> response[N];               // 1-> word, 0->nonword
    real<lower=0> rt[N];                            // rt
    
    real minRT[N];                                  // minimum RT for each subject of the observed data
    real RTbound;                                   // lower bound or RT across all subjects (e.g., 0.1 second)
                         
    vector[4] threshold_priors;                     
    vector[4] ndt_priors;
    vector[4] alpha_priors;
    vector[4] b_priors;
}

transformed data {
    matrix [N, 2] RT;

    for (n in 1:N)
    {
        RT[n, 1] = rt[n];
        RT[n, 2] = response[n];
    }
}

parameters {

    real mu_ndt;                              
    real mu_threshold_word;
    real mu_threshold_nonword;
    real mu_alpha_1;
    real mu_alpha_2;
    real mu_b;
    
    real<lower=0> sd_ndt;
    real<lower=0> sd_threshold_word;
    real<lower=0> sd_threshold_nonword;
    real<lower=0> sd_alpha_1;
    real<lower=0> sd_alpha_2;
    real<lower=0> sd_b;
    
    real z_ndt[L];
    real z_threshold_word[L];
    real z_threshold_nonword[L];
    real z_alpha_1[L];
    real z_alpha_2[L];
    real z_b[L];
    
}

transformed parameters {
    vector<lower=0>[N] drift_word_t;                     // trial-by-trial drift rate for predictions
    vector<lower=0>[N] drift_nonword_t;                  // trial-by-trial drift rate for predictions
    vector<lower=0>[N] threshold_t_word;                 // trial-by-trial word threshold
    vector<lower=0>[N] threshold_t_nonword;              // trial-by-trial nonword threshold
    vector [N] ndt_t;                                    // trial-by-trial ndt

    real<lower=0> alpha_1_sbj[L];
    real<lower=0> alpha_2_sbj[L];
    real<lower=0> b_sbj[L];
    real<lower=0> threshold_sbj_word[L];
    real<lower=0> threshold_sbj_nonword[L];
    real ndt_sbj[L];

    real<lower=0> transf_mu_alpha_1;
    real<lower=0> transf_mu_alpha_2;
    real<lower=0> transf_mu_b;
    real<lower=0> transf_mu_threshold_word;
    real<lower=0> transf_mu_threshold_nonword;
    real<lower=0> transf_mu_ndt;
    
    transf_mu_alpha_1 = log(1 + exp(mu_alpha_1));
    transf_mu_alpha_2 = log(1 + exp(mu_alpha_2));
    transf_mu_b = log(1 + exp(mu_b));
    transf_mu_threshold_word = log(1 + exp(mu_threshold_word));
    transf_mu_threshold_nonword = log(1 + exp(mu_threshold_nonword));
    transf_mu_ndt = log(1 + exp(mu_ndt));

    for (l in 1:L) {
        alpha_1_sbj[l] = log(1 + exp(mu_alpha_1 + z_alpha_1[l] * sd_alpha_1));
        alpha_2_sbj[l] = log(1 + exp(mu_alpha_2 + z_alpha_2[l] * sd_alpha_2));
        b_sbj[l] = log(1 + exp(mu_b + z_b[l] * sd_b));
        threshold_sbj_word[l] = log(1 + exp(mu_threshold_word + z_threshold_word[l] * sd_threshold_word));
        threshold_sbj_nonword[l] = log(1 + exp(mu_threshold_nonword + z_threshold_nonword[l] * sd_threshold_nonword));
        ndt_sbj[l] = log(1 + exp(mu_ndt + z_ndt[l] * sd_ndt));
    }

    for (n in 1:N) {
        drift_word_t[n] = alpha_1_sbj[participant[n]] * p[n][1] + b_sbj[participant[n]] * frequency[n];
        drift_nonword_t[n] = alpha_2_sbj[participant[n]] * p[n][2];
       
        threshold_t_word[n] = threshold_sbj_word[participant[n]];
        threshold_t_nonword[n] = threshold_sbj_nonword[participant[n]];
        
        ndt_t[n] = ndt_sbj[participant[n]] * (minRT[n] - RTbound) + RTbound;
    }
}

model {
    mu_threshold_word ~ normal(threshold_priors[1], threshold_priors[2]);
    mu_threshold_nonword ~ normal(threshold_priors[1], threshold_priors[2]);
    mu_ndt ~ normal(ndt_priors[1], ndt_priors[2]);
    mu_alpha_1 ~ normal(alpha_priors[1], alpha_priors[2]);
    mu_alpha_2 ~ normal(alpha_priors[1], alpha_priors[2]);
    mu_b ~ normal(b_priors[1], b_priors[2]);

    sd_threshold_word ~ normal(threshold_priors[3], threshold_priors[4]);
    sd_threshold_nonword ~ normal(threshold_priors[3], threshold_priors[4]);
    sd_ndt ~ normal(ndt_priors[3], ndt_priors[4]);   
    sd_alpha_1 ~ normal(alpha_priors[3], alpha_priors[4]);
    sd_alpha_2 ~ normal(alpha_priors[3], alpha_priors[4]);
    sd_b ~ normal(b_priors[3], b_priors[4]);
    
    z_threshold_word ~ normal(0, 1);
    z_threshold_nonword ~ normal(0, 1);
    z_ndt ~ normal(0, 1);
    z_alpha_1 ~ normal(0, 1);
    z_alpha_2 ~ normal(0, 1);
    z_b ~ normal(0, 1);

    RT ~ race(ndt_t, threshold_t_word, threshold_t_nonword, drift_word_t, drift_nonword_t);
}

generated quantities {
    vector[N] log_lik;
    {
        for (n in 1:N){
            log_lik[n] = race_lpdf(block(RT, n, 1, 1, 2)| segment(ndt_t, n, 1), segment(threshold_t_word, n, 1),
                                   segment(threshold_t_nonword, n, 1), segment(drift_word_t, n, 1),
                                   segment(drift_nonword_t, n, 1));
        }
    }
}