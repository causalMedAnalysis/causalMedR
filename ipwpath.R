#' Inverse probability weighting (IPW) estimator for path-specific effects: 
#' inner function
#' 
#' @description
#' Internal function used within `ipwpath()`. See the `ipwpath()` function 
#' documentation for a description of shared function arguments.
#' 
#' @noRd
ipwpath_inner <- function(
    data,
    D,
    M,
    Y,
    C = NULL,
    base_weights_name = NULL,
    stabilize = TRUE,
    censor = TRUE,
    censor_low = 0.01,
    censor_high = 0.99
) {
  # prep
  K <- length(M) # number of mediators
  n_PSE <- K + 1 # number of PSEs
  PSE <- rep(NA_real_, n_PSE) # vector to store path-specific effects
  
  
  # loop over mediators in reverse order to estimate PSEs
  for (k in rev(seq_len(K))) {
    ## PSE index
    PSE_index <- K - k + 1
    
    ## build model formulae (each model will be additive)
    ### D model 1 formula: f(D|C)
    if (is.null(C)) {
      predictors1_D <- "1"
    }
    else {
      predictors1_D <- paste(C, collapse = " + ")
    }
    formula1_D_string <- paste(D, "~", predictors1_D)
    ### D model 2 formula: s(D|C,M)
    predictors2_D <- paste(c(M[1:k],C), collapse = " + ")
    formula2_D_string <- paste(D, "~", predictors2_D)
    
    ## estimate multivariate natural effects
    est <- ipwmed_inner(
      data = data,
      D = D,
      M = M[1:k],
      Y = Y,
      formula1_string = formula1_D_string,
      formula2_string = formula2_D_string,
      base_weights_name = base_weights_name,
      stabilize = stabilize,
      censor = censor,
      censor_low = censor_low,
      censor_high = censor_high
    )
    
    ## special case: only one total mediator
    if (K==1) {
      PSE <- c(est$NDE, est$NIE)
      names(PSE) <- c("NDE", "NIE")
      ATE <- est$ATE
    }
    
    ## 2+ total mediators: last mediator
    else if (k==K) {
      PSE[[PSE_index]] <- est$NDE
      names(PSE)[PSE_index] <- "D->Y"
      prev_MNDE <- est$NDE
    }
    
    ## 2+ total mediators: first mediator
    else if (k==1) {
      PSE[[PSE_index]] <- est$NDE - prev_MNDE
      PSE[[n_PSE]] <- est$NIE
      if (k+1==K) {
        names(PSE)[PSE_index] <- paste0("D->M",k+1,"->Y")
      }
      else {
        names(PSE)[PSE_index] <- paste0("D->M",k+1,"~>Y")
      }
      names(PSE)[n_PSE] <- "D->M1~>Y"
      ATE <- est$ATE
    }
    
    ## 2+ total mediators: all other mediators
    else {
      PSE[[PSE_index]] <- est$NDE - prev_MNDE
      if (k+1==K) {
        names(PSE)[PSE_index] <- paste0("D->M",k+1,"->Y")
      }
      else {
        names(PSE)[PSE_index] <- paste0("D->M",k+1,"~>Y")
      }
      prev_MNDE <- est$NDE
    }
  }
  
  
  # compile and output
  out <- list(
    ATE = ATE,
    PSE = PSE
  )
  return(out)
}






#' Inverse probability weighting (IPW) estimator for path-specific effects
#' 
#' @description
#' `ipwpath()` uses the inverse probability weighting estimator to estimate the 
#' total effect (ATE) and path-specific effects (PSEs).
#' 
#' @details
#' TEMPORARY PLACEHOLDER
#' 
#' @param data A data frame.
#' @param D A character scalar identifying the name of the exposure variable in 
#'   `data`. `D` is a character string, but the exposure variable it identifies 
#'   must be numeric.
#' @param M A character vector (of one or more elements) identifying the names 
#'   of the mediator variables in `data`. The character vector MUST specify the 
#'   mediators in causal order, starting from the first in the hypothesized 
#'   causal sequence to the last. If you only specify a single mediator 
#'   variable, then the function will simply return the natural effects. Also 
#'   note that `M` is a character vector, but the mediator variable(s) it 
#'   identifies must each be numeric.
#' @param Y A character scalar identifying the name of the outcome variable in 
#'   `data`. `Y` is a character string, but the outcome variable it identifies 
#'   must be numeric.
#' @param C A character vector (of one or more elements) identifying the names 
#'   of the covariate variables in `data` that you wish to include in the 
#'   exposure models. If there are no such covariates you wish to include, leave 
#'   `C` as its default null argument.
#' @param base_weights_name A character scalar identifying the name of the base 
#'   weights variable in `data`, if applicable (e.g., if you have---and want to 
#'   use---sampling weights).
#' @param stabilize A logical scalar indicating whether the IPW weights should 
#'   be stabilized (multiplied by the marginal probabilities of the exposure).
#' @param censor A logical scalar indicating whether the IPW weights should 
#'   be censored.
#' @param censor_low,censor_high A pair of arguments, each a numeric scalar 
#'   denoting a probability with values in [0,1]. If the `censor` argument is 
#'   TRUE, then IPW weights below the `censor_low` quantile will be 
#'   bottom-coded, and IPW weights above the `censor_high` quantile will be 
#'   top-coded (before multiplying by a rescaled version of the base weights, if 
#'   applicable). E.g., if the default options of `censor_low = 0.01` and 
#'   `censor_high = 0.99` are used, then the IPW weights will be censored at 
#'   their 1st and 99th percentiles in the data.
#' @param boot A logical scalar indicating whether the function will perform the 
#'   nonparametric bootstrap and return two-sided confidence intervals and 
#'   p-values.
#' @param boot_reps An integer scalar for the number of bootstrap replications 
#'   to perform.
#' @param boot_conf_level A numeric scalar for the confidence level of the 
#'   bootstrap interval.
#' @param boot_seed An integer scalar specifying the random-number seed used in 
#'   bootstrap resampling.
#' @param boot_parallel A logical scalar indicating whether the bootstrap will 
#'   be performed with a parallelized loop, with the goal of reducing runtime. 
#'   Parallelized computing, as implemented in this function, requires that you 
#'   have each of the following R packages installed: `doParallel`, `doRNG`, and 
#'   `foreach`. (However, you do not need to load/attach these three packages 
#'   with the `library` function prior to running this function.) Note that the 
#'   results of the parallelized bootstrap may differ slightly from the 
#'   non-parallelized bootstrap, even if you specify the same seed, due to 
#'   differences in how the seed is processed by the two methods.
#' @param boot_cores An integer scalar specifying the number of CPU cores on 
#'   which the parallelized bootstrap will run. This argument only has an effect 
#'   if you requested a parallelized bootstrap (i.e., only if `boot` is TRUE and 
#'   `boot_parallel` is TRUE). By default, `boot_cores` is equal to the greater 
#'   of two values: (a) one and (b) the number of available CPU cores minus two. 
#'   If `boot_cores` equals one, then the bootstrap loop will not be 
#'   parallelized (regardless of whether `boot_parallel` is TRUE).
#' 
#' @returns By default, `ipwpath()` returns a list with the following elements:
#' \item{ATE}{A numeric scalar with the estimated total average treatment effect 
#'   for the exposure contrast `d - dstar`: ATE(`d`,`dstar`).}
#' \item{PSE}{A numeric vector, of length `length(M)+1`, with the estimated 
#'   path-specific effects for the exposure contrast `d - dstar`. The vector is 
#'   named with the path each effect describes.}
#' 
#' If you request the bootstrap (by setting the `boot` argument to TRUE), then 
#' the function returns all of the elements listed above, as well as the 
#' following additional elements:
#' \item{ci_ATE}{A numeric vector with the bootstrap confidence interval for the 
#'   total average treatment effect (ATE).}
#' \item{ci_PSE}{A numeric matrix with the bootstrap confidence interval for 
#'   each path-specific effect (PSE).}
#' \item{pvalue_ATE}{A numeric scalar with the p-value from a two-sided test of 
#'   whether the ATE is different from zero, as computed from the bootstrap.}
#' \item{pvalue_PSE}{A numeric matrix with each p-value from a two-sided test of 
#'   whether the PSE is different from zero, as computed from the bootstrap.}
#' \item{boot_ATE}{A numeric vector of length `boot_reps` comprising the ATE 
#'   estimates from all replicate samples created in the bootstrap.}
#' \item{boot_PSE}{A numeric matrix, of `length(M)+1` columns and `boot_reps` 
#'   rows, comprising all PSE estimates from all replicate samples created in 
#'   the bootstrap.}
#' 
#' @export
#' 
#' @examples
#' # Example 1: Two mediators
#' ## Prepare data
#' ## For convenience with this example, we will use complete cases
#' data(nlsy)
#' covariates <- c(
#'   "female",
#'   "black",
#'   "hispan",
#'   "paredu",
#'   "parprof",
#'   "parinc_prank",
#'   "famsize",
#'   "afqt3"
#' )
#' key_variables <- c(
#'   "cesd_age40",
#'   "ever_unemp_age3539",
#'   "log_faminc_adj_age3539",
#'   "att22",
#'   covariates
#' )
#' nlsy <- nlsy[complete.cases(nlsy[,key_variables]),]
#' nlsy$std_cesd_age40 <- 
#'   (nlsy$cesd_age40 - mean(nlsy$cesd_age40)) / 
#'   sd(nlsy$cesd_age40)
#' ## Estimate path-specific effects
#' ipwpath(
#'   data = nlsy,
#'   D = "att22",
#'   M = c("ever_unemp_age3539", "log_faminc_adj_age3539"),
#'   # ^ note that this order encodes our assumption that ever_unemp_age3539 
#'   # causally precedes log_faminc_adj_age3539
#'   Y = "std_cesd_age40",
#'   C = c(
#'     "female",
#'     "black",
#'     "hispan",
#'     "paredu",
#'     "parprof",
#'     "parinc_prank",
#'     "famsize",
#'     "afqt3"
#'   )
#' )
#' 
#' # Example 2: If you specify only a single mediator, the function will return 
#' # the natural effects (NDE and NIE), in addition to the ATE
#' ipwpath(
#'   data = nlsy,
#'   D = "att22",
#'   M = "ever_unemp_age3539",
#'   Y = "std_cesd_age40",
#'   C = c(
#'     "female",
#'     "black",
#'     "hispan",
#'     "paredu",
#'     "parprof",
#'     "parinc_prank",
#'     "famsize",
#'     "afqt3"
#'   )
#' )
#' 
#' # Example 3: Incorporating sampling weights
#' ipwpath(
#'   data = nlsy,
#'   D = "att22",
#'   M = c("ever_unemp_age3539", "log_faminc_adj_age3539"),
#'   Y = "std_cesd_age40",
#'   C = c(
#'     "female",
#'     "black",
#'     "hispan",
#'     "paredu",
#'     "parprof",
#'     "parinc_prank",
#'     "famsize",
#'     "afqt3"
#'   ),
#'   base_weights_name = "weight"
#' )
#' 
#' # Example 4: Perform a nonparametric bootstrap, with 2,000 replications
#' \dontrun{
#'   ipwpath(
#'     data = nlsy,
#'     D = "att22",
#'     M = c("ever_unemp_age3539", "log_faminc_adj_age3539"),
#'     Y = "std_cesd_age40",
#'     C = c(
#'       "female",
#'       "black",
#'       "hispan",
#'       "paredu",
#'       "parprof",
#'       "parinc_prank",
#'       "famsize",
#'       "afqt3"
#'     ),
#'     boot = TRUE,
#'     boot_reps = 2000,
#'     boot_seed = 1234
#'   )
#' }
#' 
#' # Example 5: Parallelize the bootstrap, to attempt to reduce runtime
#' # Note that this requires you to have installed the `doParallel`, `doRNG`, 
#' # and `foreach` packages.
#' \dontrun{
#'   ipwpath(
#'     data = nlsy,
#'     D = "att22",
#'     M = c("ever_unemp_age3539", "log_faminc_adj_age3539"),
#'     Y = "std_cesd_age40",
#'     C = c(
#'       "female",
#'       "black",
#'       "hispan",
#'       "paredu",
#'       "parprof",
#'       "parinc_prank",
#'       "famsize",
#'       "afqt3"
#'     ),
#'     boot = TRUE,
#'     boot_reps = 2000,
#'     boot_seed = 1234,
#'     boot_parallel = TRUE
#'   )
#' }
ipwpath <- function(
    data,
    D,
    M,
    Y,
    C = NULL,
    base_weights_name = NULL,
    stabilize = TRUE,
    censor = TRUE,
    censor_low = 0.01,
    censor_high = 0.99,
    boot = FALSE,
    boot_reps = 1000,
    boot_conf_level = 0.95,
    boot_seed = NULL,
    boot_parallel = FALSE,
    boot_cores = max(c(parallel::detectCores()-2,1))
) {
  # load data
  data_outer <- data
  
  
  # create adjusted boot_parallel logical
  boot_parallel_rev <- ifelse(boot_cores>1, boot_parallel, FALSE)
  
  
  # preliminary error/warning checks
  if (boot) {
    if (boot_parallel & boot_cores==1) {
      warning(paste(strwrap("Warning: You requested a parallelized bootstrap (boot=TRUE and boot_parallel=TRUE), but you do not have enough cores available for parallelization. The bootstrap will proceed without parallelization."), collapse = "\n"))
    }
    if (boot_parallel_rev & !requireNamespace("doParallel", quietly = TRUE)) {
      stop(paste(strwrap("Error: You requested a parallelized bootstrap (boot=TRUE and boot_parallel=TRUE), but the required package 'doParallel' has not been installed. Please install this package if you wish to run a parallelized bootstrap."), collapse = "\n"))
    }
    if (boot_parallel_rev & !requireNamespace("doRNG", quietly = TRUE)) {
      stop(paste(strwrap("Error: You requested a parallelized bootstrap (boot=TRUE and boot_parallel=TRUE), but the required package 'doRNG' has not been installed. Please install this package if you wish to run a parallelized bootstrap."), collapse = "\n"))
    }
    if (boot_parallel_rev & !requireNamespace("foreach", quietly = TRUE)) {
      stop(paste(strwrap("Error: You requested a parallelized bootstrap (boot=TRUE and boot_parallel=TRUE), but the required package 'foreach' has not been installed. Please install this package if you wish to run a parallelized bootstrap."), collapse = "\n"))
    }
    if (!is.null(base_weights_name)) {
      warning(paste(strwrap("Warning: You requested a bootstrap, but your design includes base sampling weights. Note that this function does not internally rescale sampling weights for use with the bootstrap, and it does not account for any stratification or clustering in your sample design. Failure to properly adjust the bootstrap sampling to account for a complex sample design that requires weighting could lead to invalid inferential statistics."), collapse = "\n"))
    }
  }
  
  
  # other error/warning checks
  if (!is.numeric(data_outer[[D]])) {
    stop(paste(strwrap("Error: The exposure variable (identified by the string argument D in data) must be numeric."), collapse = "\n"))
  }
  if (!is.numeric(data_outer[[Y]])) {
    stop(paste(strwrap("Error: The outcome variable (identified by the string argument Y in data) must be numeric."), collapse = "\n"))
  }
  if (any(is.na(data_outer[[D]]))) {
    stop(paste(strwrap("Error: There is at least one observation with a missing/NA value for the exposure variable (identified by the string argument D in data)."), collapse = "\n"))
  }
  if (any(! data_outer[[D]] %in% c(0,1))) {
    stop(paste(strwrap("Error: The exposure variable (identified by the string argument D in data) must be a numeric variable consisting only of the values 0 or 1. There is at least one observation in the data that does not meet this criteria."), collapse = "\n"))
  }
  
  
  # compute point estimates
  est <- ipwpath_inner(
    data = data_outer,
    D = D,
    M = M,
    Y = Y,
    C = C,
    base_weights_name = base_weights_name,
    stabilize = stabilize,
    censor = censor,
    censor_low = censor_low,
    censor_high = censor_high
  )
  
  
  # bootstrap, if requested
  if (boot) {
    # bootstrap function
    boot_fnc <- function() {
      # sample from the data with replacement
      boot_data <- data_outer[sample(nrow(data_outer), size = nrow(data_outer), replace = TRUE), ]
      
      # compute point estimates in the replicate sample
      boot_out <- ipwpath_inner(
        data = boot_data,
        D = D,
        M = M,
        Y = Y,
        C = C,
        base_weights_name = base_weights_name,
        stabilize = stabilize,
        censor = censor,
        censor_low = censor_low,
        censor_high = censor_high
      ) |>
        unlist()
      
      # adjust names
      names(boot_out) <- gsub("PSE\\.", "", names(boot_out))
      
      # output
      return(boot_out)
    }
    
    # parallelization prep, if parallelization requested
    if (boot_parallel_rev) {
      x_cluster <- parallel::makeCluster(boot_cores, type="PSOCK")
      doParallel::registerDoParallel(cl=x_cluster)
      parallel::clusterExport(
        cl = x_cluster, 
        varlist = c("ipwpath_inner", "ipwmed_inner", "trimQ"),
        envir = environment()
      )
      `%dopar%` <- foreach::`%dopar%`
    }
    
    # set seed
    if (!is.null(boot_seed)) {
      set.seed(boot_seed)
      if (boot_parallel) {
        doRNG::registerDoRNG(boot_seed)
      }
    }
    
    # compute estimates for each replicate sample
    if (boot_parallel_rev) {
      boot_res <- foreach::foreach(i = 1:boot_reps, .combine = rbind) %dopar% {
        boot_fnc()
      }
      boot_ATE <- boot_res[,1]
      boot_PSE <- boot_res[,-1]
    }
    else {
      boot_ATE <- rep(NA_real_, boot_reps)
      boot_PSE <- matrix(NA_real_, nrow = boot_reps, ncol = length(est$PSE))
      for (i in seq_len(boot_reps)) {
        boot_iter <- boot_fnc()
        boot_ATE[i] <- boot_iter[1]
        boot_PSE[i,] <- boot_iter[-1]
        if (i==1) {
          colnames(boot_PSE) <- names(boot_iter[-1])
        }
      }
    }
    
    # clean up
    if (boot_parallel_rev) {
      parallel::stopCluster(x_cluster)
      rm(x_cluster)
    }
    
    # compute bootstrap confidence intervals 
    # from percentiles of the bootstrap distributions
    boot_alpha <- 1 - boot_conf_level
    boot_ci_probs <- c(
      boot_alpha/2,
      1 - boot_alpha/2
    )
    boot_ci <- function(x) {
      quantile(x, probs=boot_ci_probs)
    }
    ci_ATE <- boot_ci(boot_ATE)
    ci_PSE <- apply(boot_PSE, MARGIN = 2, FUN = boot_ci) |>
      t()
    
    # compute two-tailed bootstrap p-values
    boot_pval <- function(x) {
      2 * min(
        mean(x < 0),
        mean(x > 0)
      )
    }
    pvalue_ATE <- boot_pval(boot_ATE)
    pvalue_PSE <- apply(boot_PSE, MARGIN = 2, FUN = boot_pval)
    
    # compile bootstrap results
    boot_out <- list(
      ci_ATE = ci_ATE,
      ci_PSE = ci_PSE,
      pvalue_ATE = pvalue_ATE,
      pvalue_PSE = pvalue_PSE,
      boot_ATE = boot_ATE,
      boot_PSE = boot_PSE
    )
  }
  
  
  # final output
  out <- est
  if (boot) {
    out <- append(out, boot_out)
  }
  return(out)
}

