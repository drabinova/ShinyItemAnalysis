% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/DistractorAnalysis.R
\name{DistractorAnalysis}
\alias{DistractorAnalysis}
\title{Distractor analysis}
\usage{
DistractorAnalysis(
  data,
  key,
  p.table = FALSE,
  num.groups = 3,
  matching = NULL,
  match.discrete = FALSE,
  cut.points
)
}
\arguments{
\item{data}{character: data matrix or data frame. See \strong{Details}.}

\item{key}{character: answer key for the items.}

\item{p.table}{logical: should the function return the proportions. If
\code{FALSE} (default) the counts are returned.}

\item{num.groups}{numeric: number of groups to that should be respondents
splitted.}

\item{matching}{numeric: numeric vector. If not provided, total score is
calculated and distractor analysis is performed based on it.}

\item{match.discrete}{logical: is \code{matching} discrete? Default value is
\code{FALSE}. See details.}

\item{cut.points}{numeric: numeric vector specifying cut points of
\code{matching}. See details.}
}
\description{
Performs distractor analysis for each item and optional number
  of groups.
}
\details{
This function is adapted version of
\code{\link[CTT]{distractor.analysis}} function from \code{CTT} package.

The \code{data} is a matrix or data frame whose rows represents unscored item
response from a multiple-choice test and columns correspond to the items.

The \code{key} must be a vector of the same length as \code{ncol(data)}.

In case, no \code{matching} is provided, the scores are calculated using the
item data and key. The respondents are by default splitted into the
\code{num.groups}-quantiles and the number (or proportion) of respondents in
each quantile is reported with respect to their answers. In case that
\code{matching} is discrete (\code{match.discrete = TRUE}), \code{matching}
is splitted based on its unique levels. Other cut points can be specified via
\code{cut.points} argument.
}
\examples{
# loading 100-item medical admission test data
data(dataMedicaltest, dataMedicalkey)
data <- dataMedicaltest[, 1:100]
dataBin <- dataMedical[, 1:100]
key <- unlist(dataMedicalkey)

# distractor analysis for dataMedicaltest data set
DistractorAnalysis(data, key)
\dontrun{
# distractor analysis for dataMedicaltest data set with proportions
DistractorAnalysis(data, key, p.table = TRUE)

# distractor analysis for dataMedicaltest data set for 6 groups
DistractorAnalysis(data, key, num.group = 6)

# distractor analysis for dataMedicaltest using specified matching
matching <- round(rowSums(databin), -1)
DistractorAnalysis(data, key, matching = matching)

# distractor analysis for dataMedicaltest using discrete matching
DistractorAnalysis(data, key, matching = matching, match.discrete = TRUE)

# distractor analysis for dataMedicaltest using groups specified by cut.points
DistractorAnalysis(data, key, cut.points = seq(10, 100, 10))
}

}
\author{
Adela Hladka \cr
Institute of Computer Science of the Czech Academy of Sciences \cr
Faculty of Mathematics and Physics, Charles University \cr
\email{hladka@cs.cas.cz} \cr

Patricia Martinkova \cr
Institute of Computer Science of the Czech Academy of Sciences \cr
\email{martinkova@cs.cas.cz} \cr
}
