# %%%%%%%%%%%%%%%%%%%%%%%%%%%%
# GLOBAL LIBRARY ######
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%

require(deltaPlotR)
require(DT)
require(data.table)
require(difNLR)
require(difR)
require(dplyr)
require(ggdendro)
require(ggplot2)
require(grid)
require(gridExtra)
require(knitr)
require(latticeExtra)
require(ltm)
require(mirt)
require(msm)
require(nnet)
require(plotly)
require(purrr)
require(psych)
require(psychometric) # rem. candidate
require(rmarkdown)
require(shiny)
require(shinyBS)
require(ShinyItemAnalysis)
require(shinyjs)
require(stringr)
require(tibble)
require(VGAM)
require(xtable) # could be substituted by knitr's default table engine "kable"


# %%%%%%%%%%%%%%%%%%%%%%%%%%%%
# DATA ######
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%

# maximum upload size set to 30MB
options(shiny.maxRequestSize = 30 * 1024^2)

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%
# SERVER SCRIPT ######
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%

function(input, output, session) {
  # kills the local server as the window closes
  session$onSessionEnded(function(x) {
    stopApp()
  })

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ### REACTIVE VALUES ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  # * Datasets ####
  dataset <- reactiveValues()

  dataset$binary <- NULL
  dataset$ordinal <- NULL
  dataset$nominal <- NULL
  dataset$data_type <- NULL

  dataset$key <- NULL
  dataset$minimal <- NULL
  dataset$maximal <- NULL

  dataset$group <- NULL
  dataset$criterion <- NULL
  dataset$DIFmatching <- NULL

  dataset$data_status <- NULL
  dataset$key_upload_status <- "toy"

  # * Setting ####
  setting_figures <- reactiveValues()

  setting_figures$text_size <- 12
  setting_figures$height <- 4
  setting_figures$width <- 8
  setting_figures$dpi <- 600

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ### HITS COUNTER ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  output$counter <- renderText({
    if (!file.exists("counter.Rdata")) {
      counter <- 0
    }
    else {
      load(file = "counter.Rdata")
    }
    counter <- counter + 1
    save(counter, file = "counter.Rdata")
    paste0("Hits:", counter)
  })

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # DATA UPLOAD ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  # * Load toy data ######
  observeEvent(c(input$dataSelect, removeCounter$Click == 1), {
    inputData <- input$dataSelect
    datasetName <- strsplit(inputData, split = "_")[[1]][1] # simplified dataset string division
    packageName <- strsplit(inputData, split = "_")[[1]][2]
    datasetSubset <- strsplit(inputData, split = "_")[[1]][3] # store anything after second underscore

    dataset$data_status <- "OK"

    if (datasetName == "LearningToLearn" & datasetSubset == "6") {
      do.call(data, args = list(paste0(datasetName), package = packageName))
      dataBinary <- get(paste0(datasetName))
      dataBinary <- dataBinary[19:59] # for 6th grade, items only

      group <- get(paste0(datasetName))[, "track_01"]
      criterion <- "missing"
      # DIFmatching <- get(paste0(datasetName))[, "score_9"]
      DIFmatching <- "missing"

      dataOrdinal <- dataBinary
      dataNominal <- dataBinary

      dataType <- "binary"

      key <- rep(1, ncol(dataBinary)) # key with 1 as "correct" for *n* items
    } else if (datasetName == "LearningToLearn" & datasetSubset == "9") {
      do.call(data, args = list(paste0(datasetName), package = packageName))
      dataBinary <- get(paste0(datasetName))
      dataBinary <- dataBinary[60:100] # for 9th grade, items only

      group <- get(paste0(datasetName))[, "track_01"]
      criterion <- "missing"
      DIFmatching <- get(paste0(datasetName))[, "score_6"]

      dataOrdinal <- dataBinary
      dataNominal <- dataBinary

      dataType <- "binary"

      key <- rep(1, ncol(dataBinary)) # key with 1 as "correct" for *n* items
    } else if (datasetName == "dataMedicalgraded") {
      do.call(data, args = list(paste0(datasetName), package = packageName))
      dataOrdinal <- get(paste0(datasetName))

      group <- dataOrdinal[, "gender"]
      criterion <- dataOrdinal[, "StudySuccess"]
      DIFmatching <- "missing"

      dataOrdinal <- dataOrdinal[, 1:(dim(dataOrdinal)[2] - 2)] # can be simplified with *ncol()*
      dataNominal <- dataOrdinal

      dataType <- "ordinal"

      key <- sapply(dataOrdinal, max)
      df.key <- sapply(key, rep, each = nrow(dataOrdinal))
      dataBinary <- matrix(as.numeric(dataOrdinal >= df.key),
        ncol = ncol(dataOrdinal), nrow = nrow(dataOrdinal)
      )
    } else if (datasetName == "Science") {
      do.call(data, args = list(paste0(datasetName), package = packageName))
      dataOrdinal <- get(paste0(datasetName))

      dataNominal <- dataOrdinal

      group <- "missing"
      criterion <- "missing"
      DIFmatching <- "missing"

      dataType <- "ordinal"

      key <- sapply(dataOrdinal, max)
      df.key <- sapply(key, rep, each = nrow(dataOrdinal))
      dataBinary <- matrix(as.numeric(dataOrdinal >= df.key),
        ncol = ncol(dataOrdinal), nrow = nrow(dataOrdinal)
      )
    } else {
      do.call(data, args = list(paste0(datasetName, "test"), package = packageName))
      dataNominal <- get(paste0(datasetName, "test"))

      dataType <- "nominal"

      do.call(data, args = list(paste0(datasetName, "key"), package = packageName))
      key <- as.character(unlist(get(paste0(datasetName, "key"))))
      group <- dataNominal[, length(key) + 1]
      DIFmatching <- "missing"

      if (datasetName %in% c("GMAT2", "MSATB")) {
        criterion <- "missing"
      } else {
        criterion <- dataNominal[, length(key) + 2]
      }
      dataNominal <- dataNominal[, 1:length(key)]
      dataOrdinal <- mirt::key2binary(dataNominal, key)
      dataBinary <- mirt::key2binary(dataNominal, key)
    }

    dataset$nominal <- as.data.table(dataNominal)
    dataset$ordinal <- as.data.table(dataOrdinal)
    dataset$binary <- as.data.table(dataBinary)

    dataset$data_type <- dataType

    if (input$data_type == "ordinal") {
      dataset$minimal <- sapply(dataset$ordinal, min)
      dataset$maximal <- sapply(dataset$ordinal, max)
    } else {
      dataset$minimal <- NULL
      dataset$maximal <- NULL
    }

    dataset$key <- key
    dataset$group <- group
    dataset$criterion <- criterion
    dataset$DIFmatching <- DIFmatching
  })

  # * Load data from csv files ####
  observeEvent(input$submitButton, {
    inputData <- NULL
    inputKey <- NULL
    inputGroup <- NULL
    inputCriterion <- NULL
    inputDIFmatching <- NULL # DIF matching
    inputOrdinalMin <- NULL
    inputOrdinalMax <- NULL

    inputData_type <- input$data_type

    # loading main data
    if (is.null(input$data)) {
      dataset$data_status <- "missing"

      updateSelectInput(
        session = session, inputId = "dataSelect",
        selected = "GMAT_difNLR"
      )
    } else {
      inputData <- read.csv(input$data$datapath,
        header = input$header,
        sep = input$sep,
        quote = input$quote,
        stringsAsFactors = TRUE
      )
      dataset$data_status <- "OK"

      # loading max/min values for ordinal data
      if (input$data_type == "ordinal") {
        ### changing factors to numeric
        inputData <- data.frame(sapply(inputData, function(x) as.numeric(paste(x))))

        ### minimal values
        if (is.null(input$minOrdinal)) {
          if (input$globalMin == "") {
            inputOrdinalMin <- sapply(inputData, min, na.rm = T)
          } else {
            inputOrdinalMin <- rep(input$globalMin, ncol(inputData))
          }
        } else {
          inputOrdinalMin <- read.csv(input$minOrdinal$datapath,
            header = input$header,
            sep = input$sep,
            quote = input$quote
          )
        }

        ### maximal values
        if (is.null(input$maxOrdinal)) {
          if (input$globalMax == "") {
            inputOrdinalMax <- sapply(inputData, max, na.rm = T)
          } else {
            inputOrdinalMax <- rep(input$globalMax, ncol(inputData))
          }
        } else {
          inputOrdinalMax <- read.csv(input$maxOrdinal$datapath,
            header = input$header,
            sep = input$sep,
            quote = input$quote
          )
        }
      }

      # loading key
      inpKey <- ifelse(input$data_type == "nominal",
        ifelse(is.null(input$key_nominal), 0, input$key_nominal),
        ifelse(is.null(input$key_ordinal), 0, input$key_ordinal)
      )

      if (inpKey[[1]] == 0 | dataset$key_upload_status == "reset") {
        if (input$globalCut == "") {
          if (input$data_type == "binary") {
            inputKey <- rep(1, ncol(inputData))
          } else {
            if (input$data_type == "ordinal") {
              inputKey <- inputOrdinalMax
            } else {
              inputKey <- "missing"
            }
          }
        } else {
          inputKey <- rep(as.numeric(paste(input$globalCut)), ncol(inputData))
        }
      } else {
        if (input$data_type == "nominal") {
          inputKey <- read.csv(input$key_nominal$datapath,
            header = input$header,
            sep = input$sep,
            quote = input$quote
          )
          inputKey <- as.character(unlist(inputKey))
        } else {
          inputKey <- read.csv(input$key_ordinal$datapath,
            header = input$header,
            sep = input$sep,
            quote = input$quote
          )
          inputKey <- as.character(unlist(inputKey))
        }
      }
      dataset$key <- inputKey

      # loading group
      if (is.null(input$groups)) {
        inputGroup <- "missing"
      } else {
        inputGroup <- read.csv(input$groups$datapath,
          header = input$header,
          sep = input$sep,
          quote = input$quote
        )
        inputGroup <- unlist(inputGroup)
      }

      # loading criterion
      if (is.null(input$criterion_variable)) {
        inputCriterion <- "missing"
      } else {
        inputCriterion <- read.csv(input$criterion_variable$datapath,
          header = input$header,
          sep = input$sep,
          quote = input$quote
        )
        inputCriterion <- unlist(inputCriterion)
      }

      # loading DIF matching variable
      if (is.null(input$dif_matching)) {
        inputDIFmatching <- "missing"
      } else {
        inputDIFmatching <- read.csv(input$dif_matching$datapath,
          header = input$header,
          sep = input$sep,
          quote = input$quote
        )
        inputDIFmatching <- unlist(inputDIFmatching)
      }


      # changing reactiveValues
      ### main data
      dataset$nominal <- inputData

      if (input$data_type == "nominal") {
        dataset$ordinal <- as.data.table(mirt::key2binary(dataset$nominal, inputKey))
        dataset$binary <- as.data.table(mirt::key2binary(dataset$nominal, inputKey))
      } else {
        if (input$data_type == "ordinal") {
          dataset$ordinal <- as.data.table(dataset$nominal)
          df.key <- sapply(inputKey, rep, each = nrow(inputData))
          dataset$binary <- as.data.table(matrix(as.numeric(inputData >= df.key),
            ncol = ncol(inputData), nrow = nrow(inputData)
          ))
        } else {
          dataset$ordinal <- as.data.table(dataset$nominal)
          dataset$binary <- as.data.table(dataset$nominal)
        }
      }

      dataset$nominal <- as.data.table(dataset$nominal)
      dataset$data_type <- inputData_type

      ### min/max values
      if (input$data_type == "ordinal") {
        dataset$minimal <- inputOrdinalMin
        dataset$maximal <- inputOrdinalMax
      } else {
        dataset$minimal <- NULL
        dataset$maximal <- NULL
      }
      ### group
      dataset$group <- inputGroup
      ### criterion
      dataset$criterion <- inputCriterion
      ### DIF matching
      dataset$DIFmatching <- inputDIFmatching
    }
  })

  # * Creating reactive() for data and checking ####
  nominal <- reactive({
    dataset$nominal
  })

  ordinal <- reactive({
    data <- dataset$ordinal
    if (!input$missval) {
      data[is.na(data)] <- 0
    }

    data
  })

  binary <- reactive({
    data <- dataset$binary
    if (!input$missval) {
      data[is.na(data)] <- 0
    }

    data
  })

  key <- reactive({
    if (length(dataset$key) == 1) {
      validate(need(dataset$key != "missing", "Key is missing!"),
        errorClass = "error_key_missing"
      )
    } else {
      validate(need(
        ncol(nominal()) == length(dataset$key),
        "The length of key need to be the same as number of columns in the main dataset!"
      ),
      errorClass = "error_dimension"
      )
    }
    dataset$key
  })

  minimal <- reactive({
    ### bad minimal values dimension
    validate(need(
      ncol(nominal()) == length(dataset$minimal),
      "The length of minimal values need to be the same as number of items in the main dataset!"
    ),
    errorClass = "error_dimension"
    )
    dataset$minimal
  })
  maximal <- reactive({
    ### bad maximal values dimension
    validate(need(
      ncol(nominal()) == length(dataset$maximal),
      "The length of maximal values need to be the same as number of items in the main dataset!"
    ),
    errorClass = "error_dimension"
    )
    dataset$maximal
  })

  group <- reactive({
    ### bad group dimension and warning for missing group
    if (length(dataset$group) == 1 & any(dataset$group == "missing")) {
      validate(need(
        dataset$group != "missing",
        "Group is missing! DIF and DDF analyses are not available!"
      ),
      errorClass = "warning_group_missing"
      )
    } else {
      validate(need(
        nrow(nominal()) == length(dataset$group),
        "The length of group vector needs to be the same as the number of observations in the main dataset!"
      ),
      errorClass = "error_dimension"
      )
    }
    dataset$group
  })

  criterion <- reactive({
    ### bad criterion dimension and warning for missing criterion
    if (length(dataset$criterion) == 1 & any(dataset$criterion == "missing")) {
      validate(need(
        dataset$criterion != "missing",
        "Criterion variable is missing! Predictive validity analysis is not available!"
      ),
      errorClass = "warning_criterion_variable_missing"
      )
    } else {
      validate(need(
        nrow(nominal()) == length(dataset$criterion),
        "The length of criterion variable needs to be the same as the number
                    of observations in the main dataset!"
      ),
      errorClass = "error_dimension"
      )
    }
    dataset$criterion
  })

  crit_wo_val <- reactive({
    dataset$criterion
  })

  DIFmatching <- reactive({
    ### bad DIF matching dimension and warning for missing DIF matching variable
    if (length(dataset$DIFmatching) == 1 & any(dataset$DIFmatching == "missing")) {
      validate(need(
        dataset$DIFmatching != "missing",
        "The DIF matching variable is not provided! DIF analyses will use total scores!"
      ),
      errorClass = "warning_DIFmatching_variable_missing"
      )
    } else {
      validate(need(
        nrow(nominal()) == length(dataset$DIFmatching), # changed to binary from nominal
        "The length of DIF matching variable need to be the same as number of observations in the main dataset!"
      ),
      errorClass = "error_dimension"
      )
    }
    dataset$DIFmatching
  })

  total_score <- reactive({
    rowSums(ordinal())
  })

  z_score <- reactive({
    scale(total_score())
  })

  # warning, if total_score or zscore will have NA's
  na_score <- reactive({
    if (any(is.na(total_score())) | any(is.na(z_score()))) {
      txt <- "<font color = 'orange'>
				For this analysis, observations with missing values have been omitted.
				</font>"
    } else {
      txt <- ""
    }
    txt
  })

  # warning, if total_score or zscore will have NA's - error in report
  na_score_reports <- reactive({
    if (any(is.na(total_score())) | any(is.na(z_score()))) {
      txt <- "<font color = 'orange'>
				For some analysis methods, observations with missing values have been omitted.
				</font>"
    } else {
      txt <- ""
    }
    txt
  })

  output$report_na_alert <- renderUI({
    HTML(na_score_reports())
  })

  # * Item numbers and item names ######
  item_numbers <- reactive({
    if (!input$itemnam) {
      nam <- 1:ncol(dataset$nominal)
    } else {
      nam <- colnames(dataset$nominal)
    }
    nam
  })

  item_names <- reactive({
    if (!input$itemnam) {
      nam <- paste("Item", 1:ncol(dataset$nominal))
    } else {
      nam <- colnames(dataset$nominal)
    }
    nam
  })

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # ITEM SLIDERS ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  observe({
    sliderList <- c(
      "slider_totalscores_histogram",
      "corr_plot_clust",
      "corr_plot_clust_report",
      "validitydistractorSlider",
      "distractorSlider",
      "DIF_NLR_item_plot",
      "difirt_lord_itemSlider",
      "difirt_raju_itemSlider",
      "ddfSlider",
      "reportSlider"
    )

    itemCount <- ncol(ordinal())
    minItemScore <- min(total_score(), na.rm = TRUE)
    maxItemScore <- max(c(max(total_score(), na.rm = TRUE), ncol(binary())))
    updateSliderInput(session = session, inputId = "slider_totalscores_histogram", min = minItemScore, max = maxItemScore, value = round(median(total_score(), na.rm = T)))
    updateNumericInput(session = session, inputId = "corr_plot_clust", value = 0, max = itemCount)
    updateNumericInput(session = session, inputId = "corr_plot_clust_report", value = 1, max = itemCount)
    updateSliderInput(session = session, inputId = "validitydistractorSlider", max = itemCount)
    updateSliderInput(session = session, inputId = "distractorSlider", max = itemCount, step = 1)
    updateSliderInput(session = session, inputId = "DIF_NLR_item_plot", max = itemCount)
    updateSliderInput(session = session, inputId = "difirt_lord_itemSlider", max = itemCount)
    updateSliderInput(session = session, inputId = "difirt_raju_itemSlider", max = itemCount)
    updateSliderInput(session = session, inputId = "ddfSlider", max = itemCount)
  })

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # DATA PAGE ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Data.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # SUMMARY ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Summary.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # RELIABILITY ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Reliability.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # VALIDITY ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Validity.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # TRADITIONAL ANALYSIS ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/TraditionalAnalysis.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # REGRESSION ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Regression.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # IRT MODELS WITH MIRT ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/IRT.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # DIF/FAIRNESS ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/DIF.R", local = T)

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # REPORTS ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  # * Update dataset name in Reports page ####
  dataName <- reactive({
    if (is.null(input$data)) {
      a <- input$dataSelect
      pos <- regexpr("_", a)[1]
      name <- str_sub(a, 1, pos - 1)
      if (name == "dataMedical") {
        name <- "Medical 100"
      }
      if (name == "dataMedicalgraded") {
        name <- "Medical Graded"
      }
    } else {
      name <- ""
    }
    name
  })

  observe({
    updateTextInput(
      session = session,
      inputId = "reportDataName",
      value = paste(dataName(), "dataset")
    )
  })

  # * Report format ####
  formatInput <- reactive({
    format <- input$report_format
    format
  })

  # * Setting for report ####
  # ** IRT models ####
  irt_typeInput <- reactive({
    type <- input$irt_type_report
    type
  })

  irtInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_icc()
    }
    if (type == "1pl") {
      out <- oneparamirtInput_mirt()
    }
    if (type == "2pl") {
      out <- twoparamirtInput_mirt()
    }
    if (type == "3pl") {
      out <- threeparamirtInput_mirt()
    }
    if (type == "4pl") {
      out <- irt_4PL_icc_Input()
    }
    if (type == "none") {
      out <- ""
    }

    out
  })

  irtiicInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_iic()
    }
    if (type == "1pl") {
      out <- oneparamirtiicInput_mirt()
    }
    if (type == "2pl") {
      out <- twoparamirtiicInput_mirt()
    }
    if (type == "3pl") {
      out <- threeparamirtiicInput_mirt()
    }
    if (type == "4pl") {
      out <- irt_4PL_iic_Input()
    }
    if (type == "none") {
      out <- ""
    }

    out
  })

  irttifInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_tic()
    }
    if (type == "1pl") {
      out <- oneparamirttifInput_mirt()
    }
    if (type == "2pl") {
      out <- twoparamirttifInput_mirt()
    }
    if (type == "3pl") {
      out <- threeparamirttifInput_mirt()
    }
    if (type == "4pl") {
      out <- irt_4PL_tif_Input()
    }
    if (type == "none") {
      out <- ""
    }

    out
  })

  irtcoefInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_coef()
    }
    if (type == "1pl") {
      out <- oneparamirtcoefInput_mirt()
    }
    if (type == "2pl") {
      out <- twoparamirtcoefInput_mirt()
    }
    if (type == "3pl") {
      out <- threeparamirtcoefInput_mirt()
    }
    if (type == "4pl") {
      out <- irt_4PL_coef_Input()
    }
    if (type == "none") {
      out <- ""
    }

    out
  })

  irtfactorInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_factors_plot()
    }
    if (type == "1pl") {
      out <- oneparamirtFactorInput_mirt()
    }
    if (type == "2pl") {
      out <- twoparamirtFactorInput_mirt()
    }
    if (type == "3pl") {
      out <- threeparamirtFactorInput_mirt()
    }
    if (type == "4pl") {
      out <- irt_4PL_factorscores_plot_Input()
    }
    if (type == "none") {
      out <- ""
    }

    out
  })

  irtabilityTableInput <- reactive({
    type <- input$irt_type_report
    if (type == "rasch") {
      out <- irt_rasch_factors()[, 1:3]
    }
    if (type == "1pl") {
      out <- onePlAbilities()[, 1:3]
    }
    if (type == "2pl") {
      out <- twoPlAbilities()[, 1:3]
    }
    if (type == "3pl") {
      out <- threePlAbilities()[, 1:3]
    }
    if (type == "4pl") {
      out <- fourPlAbilities()[, 1:3]
    }
    if (type == "none") {
      out <- ""
    }

    if (type != "none") {
      out <- data.table(
        Min = sapply(out, min),
        Max = sapply(out, max),
        Mean = sapply(out, mean),
        Median = sapply(out, median),
        SD = sapply(out, sd),
        Skewness = sapply(out, ShinyItemAnalysis:::skewness),
        Kurtosis = sapply(out, ShinyItemAnalysis:::kurtosis)
      )
      rownames(out) <- c("Total Scores", "Z-Scores", "F-scores")
    }
    out
  })

  # * Double slider inicialization for DD plot report ######
  observe({
    val <- input$DDplotNumGroupsSlider_report
    updateSliderInput(session, "DDplotRangeSlider_report",
      min = 1,
      max = val,
      step = 1,
      value = c(1, val)
    )
  })

  # * Group present ####
  groupPresent <- reactive({
    (any(dataset$group != "missing") | is.null(dataset$group))
  })

  # * Critetion present ####
  criterionPresent <- reactive({
    (any(dataset$criterion != "missing") | is.null(dataset$criterion))
  })

  # * DIF matching present ####
  DIFmatchingPresent <- reactive({
    (any(dataset$DIFmatching != "missing") | is.null(dataset$DIFmatching))
  })

  # * Progress bar ####
  observeEvent(input$generate, {
    withProgress(message = "Creating content", value = 0, style = "notification", {
      list( # header
        author = input$reportAuthor,
        dataset = input$reportDataName,
        # datasets
        a = nominal(),
        k = key(),
        itemNames = item_names(),
        # total scores
        incProgress(0.05),
        results = t(totalscores_table_Input()),
        histogram_totalscores = totalscores_histogram_Input(),
        cutScore = input$slider_totalscores_histogram,
        # standard scores
        standardscores_table = standardscores_table_Input(),
        incProgress(0.05),
        # validity section
        corr_plot = {
          if (input$corr_report) {
            if (input$customizeCheck) {
              corr_plot_Input_report()
            } else {
              corr_plot_Input()
            }
          } else {
            ""
          }
        },
        corr_plot_numclust = ifelse(input$customizeCheck, input$corr_plot_clust_report, input$corr_plot_clust),
        corr_plot_clustmethod = ifelse(input$customizeCheck, input$corr_plot_clustmethod_report, input$corr_plot_clustmethod),
        corr_type = ifelse(input$customizeCheck, input$corr_plot_type_of_corr_report, input$type_of_corr),
        scree_plot = {
          if (input$corr_report) {
            scree_plot_Input()
          } else {
            ""
          }
        },
        isCriterionPresent = criterionPresent(),
        validity_check = input$predict_report,
        validity_plot = {
          if (input$predict_report) {
            if (criterionPresent()) {
              validity_plot_Input()
            } else {
              ""
            }
          }
        },
        validity_table = {
          if (input$predict_report) {
            if (criterionPresent()) {
              validity_table_Input()
            } else {
              ""
            }
          }
        },
        incProgress(0.05),
        # item analysis
        DDplot = DDplot_Input_report(),
        DDplotRange1 = ifelse(input$customizeCheck, input$DDplotRangeSlider_report[[1]], input$DDplotRangeSlider[[1]]),
        DDplotRange2 = ifelse(input$customizeCheck, input$DDplotRangeSlider_report[[2]], input$DDplotRangeSlider[[2]]),
        DDplotNumGroups = ifelse(input$customizeCheck, input$DDplotNumGroupsSlider_report, input$DDplotNumGroupsSlider),
        DDplotDiscType = ifelse(input$customizeCheck, input$DDplotDiscriminationSelect_report, input$DDplotDiscriminationSelect),
        itemexam = itemanalysis_table_report_Input(),
        cronbachs_alpha_table = reliability_cronbachalpha_table_Input(),
        incProgress(0.05),
        # distractors
        distractor_plot = report_distractor_plot(),
        type_distractor_plot = input$type_combinations_distractor_report,
        distractor_plot_legend_length = report_distractor_plot_legend_length(),
        incProgress(0.25),
        # regression
        multiplot = report_regression_multinomial_plot(),
        incProgress(0.05),
        # irt
        wrightMap = oneparamirtWrightMapInput_mirt(),
        irt_type = irt_typeInput(),
        irt = irtInput(),
        irtiic = irtiicInput(),
        irttif = irttifInput(),
        irtcoef = irtcoefInput(),
        irtfactor = irtfactorInput(),
        irtability = irtabilityTableInput(),
        incProgress(0.25),
        # DIF
        ### presence of group vector
        isGroupPresent = groupPresent(),
        ### histograms by group
        histCheck = input$histCheck,
        DIF_total_table = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_table_Input()
            }
          }
        },
        DIF_total_hist = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_hist_Input()
            }
          }
        },
        DIF_total_ttest = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_ttest_Input()
            }
          }
        },
        ### delta plot
        deltaplotCheck = input$deltaplotCheck,
        deltaplot = {
          if (groupPresent()) {
            if (input$deltaplotCheck) {
              deltaplotInput_report()
            }
          }
        },
        DP_text_normal = {
          if (groupPresent()) {
            if (input$deltaplotCheck) {
              deltaGpurn_report()
            }
          }
        },
        ### Mantel-Haenszel
        MHCheck = input$MHCheck,
        DIF_MH_print = {
          if (groupPresent()) {
            if (input$MHCheck) {
              report_DIF_MH_model()
            }
          }
        },
        ### logistic regression
        logregCheck = input$logregCheck,
        DIF_logistic_plot = {
          if (groupPresent()) {
            if (input$logregCheck) {
              report_DIF_logistic_plot()
            }
          }
        },
        DIF_logistic_print = {
          if (groupPresent()) {
            if (input$logregCheck) {
              report_DIF_logistic_model()
            }
          }
        },
        ### DDF multinomial
        multiCheck = input$multiCheck,
        DDF_multinomial_print = {
          if (groupPresent()) {
            if (input$multiCheck) {
              DDF_multi_model_report()
            }
          }
        },
        DDF_multinomial_plot = {
          if (groupPresent()) {
            if (input$multiCheck) {
              DDF_multi_plot_report()
            }
          }
        },
        incProgress(0.25),
        ### sessionInfo
        sessionInfo = input$include_session
      )
    })

    output$download_report_button <- renderUI({
      if (is.null(input$generate)) {
        return(NULL)
      }
      downloadButton(
        outputId = "report",
        label = "Download report",
        class = "btn btn-primary"
      )
    })
  })

  # * Download report ####
  output$report <- downloadHandler(
    filename = reactive({
      paste0("report.", input$report_format)
    }),
    content = function(file) {
      reportPath <- file.path(getwd(), paste0("report", formatInput(), ".Rmd"))
      parameters <- list( # header
        author = input$reportAuthor,
        dataset = input$reportDataName,
        # datasets
        a = nominal(),
        k = key(),
        itemNames = item_names(),
        # total scores
        totalscores_table = t(totalscores_table_Input()),
        histogram_totalscores = totalscores_histogram_Input(),
        cutScore = input$slider_totalscores_histogram,
        # standard scores
        standardscores_table = standardscores_table_Input(),
        # validity section
        corr_plot = {
          if (input$corr_report) {
            if (input$customizeCheck) {
              corr_plot_Input_report()
            } else {
              corr_plot_Input()
            }
          } else {
            ""
          }
        },
        corr_plot_numclust = ifelse(input$customizeCheck, input$corr_plot_clust_report, input$corr_plot_clust),
        corr_plot_clustmethod = ifelse(input$customizeCheck, input$corr_plot_clustmethod_report, input$corr_plot_clustmethod),
        corr_type = ifelse(input$customizeCheck, input$corr_plot_type_of_corr_report, input$type_of_corr),
        scree_plot = {
          if (input$corr_report) {
            scree_plot_Input()
          } else {
            ""
          }
        },
        isCriterionPresent = criterionPresent(),
        validity_check = input$predict_report,
        validity_plot = {
          if (input$predict_report) {
            if (criterionPresent()) {
              validity_plot_Input()
            } else {
              ""
            }
          }
        },
        validity_table = {
          if (input$predict_report) {
            if (criterionPresent()) {
              validity_table_Input()
            } else {
              ""
            }
          }
        },
        # item analysis
        DDplot = DDplot_Input_report(),
        DDplotRange1 = ifelse(input$customizeCheck, input$DDplotRangeSlider_report[[1]], input$DDplotRangeSlider[[1]]),
        DDplotRange2 = ifelse(input$customizeCheck, input$DDplotRangeSlider_report[[2]], input$DDplotRangeSlider[[2]]),
        DDplotNumGroups = ifelse(input$customizeCheck, input$DDplotNumGroupsSlider_report, input$DDplotNumGroupsSlider),
        DDplotDiscType = ifelse(input$customizeCheck, input$DDplotDiscriminationSelect_report, input$DDplotDiscriminationSelect),
        itemexam = itemanalysis_table_report_Input(),
        cronbachs_alpha_table = reliability_cronbachalpha_table_Input(),
        # distractors
        distractor_plot = report_distractor_plot(),
        type_distractor_plot = input$type_combinations_distractor_report,
        distractor_plot_legend_length = report_distractor_plot_legend_length(),
        # regression
        multiplot = report_regression_multinomial_plot(),
        # irt
        wrightMap = oneparamirtWrightMapInput_mirt(),
        irt_type = irt_typeInput(),
        irt = irtInput(),
        irtiic = irtiicInput(),
        irttif = irttifInput(),
        irtcoef = irtcoefInput(),
        irtfactor = irtfactorInput(),
        irtability = irtabilityTableInput(),
        # DIF
        ### presence of group vector
        isGroupPresent = groupPresent(),
        ### histograms by groups
        histCheck = input$histCheck,
        DIF_total_table = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_table_Input()
            }
          }
        },
        DIF_total_hist = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_hist_Input()
            }
          }
        },
        DIF_total_ttest = {
          if (groupPresent()) {
            if (input$histCheck) {
              DIF_total_ttest_Input()
            }
          }
        },
        ### delta plot
        deltaplotCheck = input$deltaplotCheck,
        DIF_deltaplot = {
          if (groupPresent()) {
            if (input$deltaplotCheck) {
              deltaplotInput_report()
            }
          }
        },
        DIF_deltaplot_text = {
          if (groupPresent()) {
            if (input$deltaplotCheck) {
              deltaGpurn_report()
            }
          }
        },
        ### Mantel-Haenszel
        MHCheck = input$MHCheck,
        DIF_MH_print = {
          if (groupPresent()) {
            if (input$MHCheck) {
              report_DIF_MH_model()
            }
          }
        },
        ### logistic regression
        logregCheck = input$logregCheck,
        DIF_logistic_plot = {
          if (groupPresent()) {
            if (input$logregCheck) {
              report_DIF_logistic_plot()
            }
          }
        },
        DIF_logistic_print = {
          if (groupPresent()) {
            if (input$logregCheck) {
              report_DIF_logistic_model()
            }
          }
        },
        ### multinomial regression
        multiCheck = input$multiCheck,
        DDF_multinomial_print = {
          if (groupPresent()) {
            if (input$multiCheck) {
              DDF_multi_model_report()
            }
          }
        },
        DDF_multinomial_plot = {
          if (groupPresent()) {
            if (input$multiCheck) {
              DDF_multi_plot_report()
            }
          }
        },
        ### sessionInfo
        sessionInfo = input$include_session
      )
      rmarkdown::render(reportPath,
        output_file = file,
        params = parameters, envir = new.env(parent = globalenv())
      )
    }
  )

  # source('tests/helper_functions/markdown_render.R', local = TRUE)
  #
  # exportTestValues(report = report_react())

  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  # SETTING ######
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%%

  source("server/Setting.R", local = T)


  # url resolver
  observe({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(names(query)) && names(query) == "print_version") {
      session$sendCustomMessage("sessinf", sessionInfo())
    }
  })
}
