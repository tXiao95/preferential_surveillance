

#' preferentialSampling
#'
#' @param data List. Data input containing case, control counts, covariates.
#' @param d Matrix. Distance matrix for grid cells in study region.
#' @param n.sample Numeric. Number of MCMC samples to generate.
#' @param burnin Numeric. Number of MCMC samples to discard as burnin.
#' @param L_w Numeric. HMC simulation length parameter for spatial random effects.
#' @param L_ca Numeric. HMC simulation length parameter for case covariates.
#' @param L_co Numeric. HMC simulation length parameter for control covariates.
#' @param L_a_ca Numeric. HMC simulation length parameter for case preferential sampling parameter.
#' @param L_a_co Numeric. HMC simulation length parameter for control preferential sampling parameter.
#' @param proposal.sd.theta Numeric. Standard deviation of proposal distribution for spatial range parameter.
#' @param m_aca Numeric. Number of samples to apply self tuning for case preferential sampling parameter.
#' @param m_aco Numeric. Number of samples to apply self tuning for control preferential sampling parameter.
#' @param m_ca Numeric. Number of samples to apply self tuning for case covariates.
#' @param m_co Numeric. Number of samples to apply self tuning for control covariates.
#' @param m_w Numeric. Number of samples to apply self tuning for spatial random effects.
#' @param target_aca Numeric. Target acceptance rate for case preferential sampling parameter.
#' @param target_aco Numeric. Target acceptance rate for control preferential sampling parameter.
#' @param target_ca Numeric. Target acceptance rate for case covariates.
#' @param target_co Numeric. Target acceptance rate for control covariates.
#' @param target_w Numeric. Target acceptance rate for spatial random effects.
#' @param target_loc Numeric. Target acceptance rate for locational covariates.
#' @param self_tune_w Logical. Whether to apply self tuning for spatial random effects.
#' @param self_tune_aca Logical. Whether to apply self tuning for case preferential sampling paramter.
#' @param self_tune_aco Logical. Whether to apply self tuning for control preferential sampling paramter.
#' @param self_tune_ca Logical. Whether to apply self tuning for case covariates.
#' @param self_tune_co Logical. Whether to apply self tuning for control covariates.
#' @param self_tune_loc Logical. Whether to apply self tuning for locational covariates.
#' @param delta_w Numeric. Required if self_tune_w is FALSE. HMC step size for spatial random effects.
#' @param delta_aca Numeric. Required if self_tune_w is FALSE. HMC step size for case preferential sampling parameter.
#' @param delta_aco Numeric. Required if self_tune_w is FALSE. HMC step size for control preferential sampling parameter.
#' @param delta_ca Numeric. Required if self_tune_w is FALSE. HMC step size for case covariates.
#' @param delta_co Numeric. Required if self_tune_w is FALSE. HMC step size for control covariates.
#' @param delta_loc Numeric. Required if self_tune_w is FALSE. HMC step size for locational covariates.
#' @param beta_ca_initial Numeric. Initial MCMC value for case covariate parameter.
#' @param beta_co_initial Numeric. Initial MCMC value for control covariate parameter.
#' @param alpha_ca_initial Numeric. Initial MCMC value for case preferential sampling parameter.
#' @param alpha_co_initial Numeric. Initial MCMC value for control preferential sampling parameter.
#' @param beta_loc_initial Numeric. Initial MCMC value for locational covariate parameter.
#' @param theta_initial Numeric. Initial MCMC value for spatial range parameter.
#' @param phi_initial Numeric. Initial MCMC value for spatial marginal variance parameter.
#' @param w_initial Numeric. Initial MCMC value for spatial random effects.
#' @param prior_phi List. Shape and scale values for prior distribution (Inverse Gamma) of marginal variance.
#' @param prior_theta List. Shape and scale values for prior distribution (Gamma) of spatial range.
#' @param prior_alpha_ca_var List. Prior (Independent Normal) variance of case covariates.
#' @param prior_alpha_co_var List. Prior (Independent Normal) variance of control covariates.
#'
#' @return List containing posterior samples and associated tuning values.
#' @export
preferentialSampling <- function(data, d, n.sample, burnin,
                                 L_w, L_ca, L_co, L_a_ca, L_a_co,
                                 proposal.sd.theta=0.3,
                                 m_aca=2000, m_aco=2000, m_ca=700, m_co=700, m_w=700, 
                                 target_aca=0.75, target_aco=0.75, target_ca=0.75, target_co=0.75, target_w=0.75, target_loc=0.75,
                                 self_tune_w=TRUE, self_tune_aca=TRUE, self_tune_aco=TRUE, self_tune_ca=TRUE, self_tune_co=TRUE, self_tune_loc=TRUE,
                                 delta_w=NULL, delta_aca=NULL, delta_aco=NULL, delta_ca=NULL, delta_co=NULL, delta_loc=NULL,
                                 beta_ca_initial=NULL, beta_co_initial=NULL, alpha_ca_initial=NULL, alpha_co_initial=NULL, beta_loc_initial=NULL,
                                 theta_initial=NULL, phi_initial=NULL, w_initial=NULL,
                                 prior_phi, prior_theta, prior_alpha_ca_var, prior_alpha_co_var){
  
  
  ## setup
  case.data <- data$case.data
  ctrl.data <- data$ctrl.data
  locs <- data$loc
  X.c <- case.data$x.standardised
  X.loc <- data$loc$x.scaled
  Y.ca <- case.data$y
  Y.co <- ctrl.data$y
  Y.l <- locs$status
  N.w <- length(locs$status)
  
  
  ## starting values
  if (is.null(w_initial)){
    w.i <- rnorm(N.w)
  } else {
    w.i <- w_initial
  }
  if (is.null(beta_ca_initial)){
    beta.ca <- rnorm(ncol(X.c))
  } else {
    beta.ca <- beta_ca_initial
  }
  if (is.null(beta_co_initial)){
    beta.co <- rnorm(ncol(X.c))
  } else {
    beta.co <- beta_co_initial
  }
  if (is.null(beta_loc_initial)){
    beta.loc <- rnorm(ncol(X.c))
  } else {
    beta.loc <- beta_loc_initial
  }
  if (is.null(alpha_ca_initial)){
    alpha.ca.i <- runif(1, 1, 3)
  } else {
    alpha.ca.i <- alpha_ca_initial
  }
  if (is.null(alpha_co_initial)){
    alpha.co.i <- runif(1, -3, -1)
  } else {
    alpha.co.i <- alpha_co_initial
  }
  if (is.null(theta_initial)){
    theta.i <- runif(1, 5, 7)
  } else {
    theta.i <- theta_initial
  }
  if (is.null(phi_initial)){
    phi.i <- runif(1, 3.5, 4.5)
  } else {
    phi.i <- phi_initial
  }
  p.c <- length(beta.ca)
  
  
  # storage
  n.keep <- n.sample - burnin
  samples.w <- array(NA, c(n.keep, length(Y.l)))
  samples.theta <- array(NA, c(n.keep, 1))
  samples.phi <- array(NA, c(n.keep, 1))
  samples.alpha.ca <- array(NA, c(n.keep, 1))
  samples.alpha.co <- array(NA, c(n.keep, 1))
  samples.beta.ca <- array(NA, c(n.keep, length(beta.ca)))
  samples.beta.co <- array(NA, c(n.keep, length(beta.co)))
  samples.beta.loc <- array(NA, c(n.keep, length(beta.loc)))
  
  
  if (self_tune_w){
    w_tuning <- initialize_tuning(m=m_w, target=target_w)
  } else {
    w_tuning <- list(delta_curr=delta_w)
  }
  if (self_tune_aca){
    a_ca_tuning <- initialize_tuning(m=m_aca, target=target_aca)
  } else {
    a_ca_tuning <- list(delta_curr=delta_aca)
  }
  if (self_tune_aco){
    a_co_tuning <- initialize_tuning(m=m_aco, target=target_aco)
  } else {
    a_co_tuning <- list(delta_curr=delta_aco)
  }
  if (self_tune_ca){
    ca_tuning <- initialize_tuning(m=m_ca, target=target_ca)
  } else {
    ca_tuning <- list(delta_curr=delta_ca)
  }
  if (self_tune_co){
    co_tuning <- initialize_tuning(m=m_co, target=target_co)
  } else {
    co_tuning <- list(delta_curr=delta_co)
  }
  if (self_tune_loc){
    loc_tuning <- initialize_tuning(m=m_loc, target=target_loc)
  } else {
    loc_tuning <- list(delta_curr=delta_loc)
  }
  
  deltas_w <- c()
  deltas_ca <- c()
  deltas_co <- c()
  deltas_aca <- c()
  deltas_aco <- c()
  deltas_loc <- c()
  
  accept <- rep(0, 7)
  
  progressBar <- txtProgressBar(style = 3)
  percentage.points <- round((1:100/100)*n.sample)
  
  for (i in 1:n.sample){
    
    ## sample from beta (location)
    beta.out.loc <- betaLocHmcUpdate(Y.l, w.i, X.loc, beta.loc, loc_tuning$delta_curr, L_loc)
    beta.loc <- beta.out.loc$b
    
    ## sample from w
    sigma.i <- Exponential(d, range=theta.i, phi=phi.i)
    sigma.inv.i <- solve(sigma.i)
    w.out.i <- wHmcUpdate(Y.l, X.c, X.loc, Y.ca, alpha.ca.i, beta.ca, beta.loc, Y.co,
                            alpha.co.i, beta.co, w.i, sigma.i, sigma.inv.i, locs, w_tuning$delta_curr, L_w, offset=0)
    w.i <- w.out.i$w
    
    ## sample from theta
    theta.out <- rangeMhUpdate(theta.i, as.numeric(w.i), d, phi.i, proposal.sd.theta, a=prior_theta[1], b=prior_theta[2])
    theta.i <- theta.out$theta
    
    ## sample from phi
    R.i <- sigma.i/phi.i
    phi.i <- 1/rgamma(1, N.w/2 + prior_phi[1], t(w.i) %*% solve(R.i) %*% w.i/2 + prior_phi[2])
    
    ## sample from beta.case
    w.i.sub <- w.i[locs$ids]
    beta.out.ca <- betaHmcUpdate(Y.ca, w.i[locs$ids], X.c, beta.ca, alpha.ca.i, ca_tuning$delta_curr, L_ca, offset=0)
    beta.ca <- beta.out.ca$beta
    
    ## sample from alpha case
    alpha.out.ca <- alphaHmcUpdate(Y.ca, w.i.sub, X.c, beta.ca, alpha.ca.i, 
                                   a_ca_tuning$delta_curr, prior_alpha_ca_mean, prior_alpha_ca_var, L_a_ca, offset=0)
    alpha.ca.i <- alpha.out.ca$alpha
    
    ## sample from beta.ctrl
    beta.out.co <- betaHmcUpdate(Y.co, w.i[locs$ids], X.c, beta.co, alpha.co.i, co_tuning$delta_curr, L_co, offset=0)
    beta.co <- beta.out.co$beta
    
    ## sample from alpha control
    alpha.out.co <- alphaHmcUpdate(Y.co, w.i.sub, X.c, beta.co, alpha.co.i, 
                                   a_co_tuning$delta_curr, prior_alpha_co_mean, prior_alpha_co_var, L_a_co, offset=0)
    alpha.co.i <- alpha.out.co$alpha
    
    if (i > burnin){
      
      j <- i - burnin
      
      samples.beta.ca[j,] <- beta.ca
      samples.beta.co[j,] <- beta.co
      samples.beta.loc[j,] <- beta.loc
      samples.alpha.ca[j,] <- alpha.ca.i
      samples.alpha.co[j,] <- alpha.co.i
      samples.theta[j,] <- theta.i
      samples.phi[j,] <- phi.i
      samples.w[j,] <- t(w.i)
      
      accept[1] <- accept[1] + w.out.i$accept
      accept[2] <- accept[2] + theta.out$accept
      accept[3] <- accept[3] + beta.out.ca$accept
      accept[4] <- accept[4] + beta.out.co$accept
      accept[5] <- accept[5] + alpha.out.ca$accept
      accept[6] <- accept[6] + alpha.out.co$accept
      accept[7] <- accept[7] + beta.out.loc$accept
      
    }
    
    if (self_tune_w){
      w_tuning <- update_tuning(w_tuning, w.out.i$a, i, w.out.i$accept)
      deltas_w <- c(deltas_w, w_tuning$delta_curr)
    }
    if (self_tune_aca){
      a_ca_tuning <- update_tuning(a_ca_tuning, alpha.out.ca$a, i, alpha.out.ca$accept)
      deltas_aca <- c(deltas_aca, a_ca_tuning$delta_curr)
    }
    if (self_tune_aco){
      a_co_tuning <- update_tuning(a_co_tuning, alpha.out.co$a, i, alpha.out.co$accept)
      deltas_aco <- c(deltas_aco, a_co_tuning$delta_curr)
    }
    if (self_tune_ca){
      ca_tuning <- update_tuning(ca_tuning, beta.out.ca$a, i, beta.out.ca$accept)
      deltas_ca <- c(deltas_ca, ca_tuning$delta_curr)
    }
    if (self_tune_co){
      co_tuning <- update_tuning(co_tuning, beta.out.co$a, i, beta.out.co$accept)
      deltas_co <- c(deltas_co, co_tuning$delta_curr)
    }
    if (self_tune_loc){
      loc_tuning <- update_tuning(loc_tuning, beta.out.loc$a, i, beta.out.loc$accept)
      deltas_loc <- c(deltas_loc, loc_tuning$delta_curr)
    }
    
    if(i %in% percentage.points){
      setTxtProgressBar(progressBar, i/n.sample)
    }
    
  }
  
  accept <- accept/n.keep
  
  output <- list()
  output$accept <- accept
  output$samples.beta.ca <- samples.beta.ca
  output$samples.beta.co <- samples.beta.co
  output$samples.alpha.ca <- samples.alpha.ca
  output$samples.alpha.co <- samples.alpha.co
  output$samples.theta <- samples.theta
  output$samples.phi <- samples.phi
  output$samples.w <- samples.w
  output$samples.beta.loc <- samples.beta.loc
  output$deltas_w <- deltas_w
  output$deltas_aca <- deltas_aca
  output$deltas_aco <- deltas_aco
  output$deltas_ca <- deltas_ca
  output$deltas_co <- deltas_co
  output$deltas_loc <- deltas_loc
  output$L_w <- L_w
  output$L_ca <- L_ca
  output$L_co <- L_co
  output$L_a_ca <- L_a_ca 
  output$L_a_co <- L_a_co
  output$L_loc <- L_loc
  output$proposal.sd.theta <- proposal.sd.theta
  output$prior_phi <- prior_phi
  output$prior_theta <- prior_theta
  output$prior_alpha_ca_var <- prior_alpha_ca_var
  output$prior_alpha_co_var <- prior_alpha_co_var
  output$n.sample <- n.sample
  output$burnin <- burnin
  
  return(output)
  
}


#' Apply Burnin to MCMC Samples
#' 
#' This function truncates the first n.burn posterior samples of the
#' output of the preferentialSampling function.
#'
#' @param output List. Output of the preferentialSampling.
#' @param n.burn Numeric. Number of samples to discard in burnin.
#'
#' @return List. Identical to the output of preferentialSampling but with truncated posterior samples.
#' @export
burnin_after <- function(output, n.burn){
  
  n.curr <- output$n.sample - output$burnin
  i.start <- n.burn + 1
  output$burnin <- output$burnin + n.burn
  
  output$samples.alpha.ca <- output$samples.alpha.ca[i.start:n.curr]
  output$samples.alpha.co <- output$samples.alpha.co[i.start:n.curr]
  output$samples.beta.ca <- output$samples.beta.ca[i.start:n.curr,]
  output$samples.beta.co <- output$samples.beta.co[i.start:n.curr,]
  output$samples.beta.loc <- output$samples.beta.loc[i.start:n.curr,]
  output$samples.w <- output$samples.w[i.start:n.curr,]
  output$samples.phi <- output$samples.phi[i.start:n.curr]
  output$samples.theta <- output$samples.theta[i.start:n.curr]
  return(output)
  
}


#' Continue running MCMC
#' 
#' This function continues to run the MCMC sampling routine for the 
#' preferentialSampling model.
#'
#' @param data List. Input data for the model.
#' @param D Matrix. distance matrix describing grid cells in study region.
#' @param output List. Output of the preferentialSampling function.
#' @param n.sample Numeric. Number of additional MCMC samples to generate.
#'
#' @return a list of posterior samples and associated quantities
#' @export
continue_mcmc <- function(data, D, output, n.sample){
  
  # get initial values
  n.sample.old <- nrow(output$samples.beta.ca)
  beta_ca_initial <- output$samples.beta.ca[n.sample.old,]
  beta_co_initial <- output$samples.beta.co[n.sample.old,]
  beta_loc_initial <- output$samples.beta.loc[n.sample.old,]
  alpha_ca_initial <- output$samples.alpha.ca[n.sample.old]
  alpha_co_initial <- output$samples.alpha.co[n.sample.old]
  w_initial <- output$samples.w[n.sample.old,]
  theta_initial <- output$samples.theta[n.sample.old]
  phi_initial <- output$samples.phi[n.sample.old]
  
  # get tuning parameters
  delta_w <- tail(output$deltas_w, 1)
  delta_aca <- tail(output$deltas_aca, 1)
  delta_aco <- tail(output$deltas_aco, 1)
  delta_ca <- tail(output$deltas_ca, 1)
  delta_co <- tail(output$deltas_co, 1)
  delta_loc <- tail(output$deltas_loc, 1)
  L_w <- output$L_w
  L_ca <- output$L_ca
  L_co <- output$L_co
  L_a_ca <- output$L_a_ca 
  L_a_co <- output$L_a_co
  L_loc <- output$L_loc
  proposal.sd.theta <- output$proposal.sd.theta
  
  # get priors
  prior_phi <- output$prior_phi
  prior_theta <- output$prior_theta
  prior_alpha_ca_var <- output$prior_alpha_ca_var
  prior_alpha_co_var <- output$prior_alpha_co_var
  more_output <- preferentialSampling(data, D, n.sample, burnin=0, 
                                      L_w=L_w, L_ca=L_ca, L_co=L_co, L_a_ca=L_a_ca, L_a_co=L_a_co,
                                      proposal.sd.theta=proposal.sd.theta,
                                      self_tune_w=FALSE, self_tune_aca=FALSE, self_tune_aco=FALSE, self_tune_ca=FALSE, self_tune_co=FALSE, self_tune_loc=FALSE,
                                      delta_w=delta_w, delta_aca=delta_aca, delta_aco=delta_aco, delta_ca=delta_ca, delta_co=delta_co, delta_loc=delta_loc,
                                      beta_ca_initial=beta_ca_initial, beta_co_initial=beta_co_initial, 
                                      alpha_ca_initial=alpha_ca_initial, alpha_co_initial=alpha_co_initial, beta_loc_initial=beta_loc_initial,
                                      theta_initial=theta_initial, phi_initial=phi_initial, w_initial=w_initial,
                                      prior_phi=prior_phi, prior_theta=prior_theta, prior_alpha_ca_var=prior_alpha_ca_var, 
                                      prior_alpha_co_var=prior_alpha_ca_var)
  
  # combine outputs
  new_output <- output
  new_output$samples.alpha.ca <- c(new_output$samples.alpha.ca, more_output$samples.alpha.ca)
  new_output$samples.alpha.co <- c(new_output$samples.alpha.co, more_output$samples.alpha.co)
  new_output$samples.beta.ca <- rbind(new_output$samples.beta.ca, more_output$samples.beta.ca)
  new_output$samples.beta.co <- rbind(new_output$samples.beta.co, more_output$samples.beta.co)
  new_output$samples.beta.loc <- rbind(new_output$samples.beta.loc, more_output$samples.beta.loc)
  new_output$samples.phi <- c(new_output$samples.phi, more_output$samples.phi)
  new_output$samples.theta <- c(new_output$samples.theta, more_output$samples.theta)
  new_output$samples.w <- rbind(new_output$samples.w, more_output$samples.w)
  new_output$deltas_aca <- c(new_output$deltas_aca, more_output$deltas_aca)
  new_output$deltas_aco <- c(new_output$deltas_aco, more_output$deltas_aco)
  new_output$deltas_co <- c(new_output$deltas_co, more_output$deltas_co)
  new_output$deltas_ca <- c(new_output$deltas_ca, more_output$deltas_ca)
  new_output$deltas_w <- c(new_output$deltas_w, more_output$deltas_w)
  new_output$deltas_loc <- c(new_output$deltas_loc, more_output$deltas_loc)
  new_output$n.sample <- new_output$n.sample + n.sample
  new_output$accept <- (new_output$n.sample * new_output$accept + n.sample * more_output$accept)/(new_output$n.sample + n.sample)
  
  return(new_output)
  
}
