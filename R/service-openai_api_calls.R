#' Base for a request to the OPENAI API
#'
#' This function sends a request to a specific OpenAI API \code{task} endpoint at the base URL \code{https://api.openai.com/v1}, and authenticates with an API key using a Bearer token.
#'
#' @param task character string specifying an OpenAI API endpoint task
#' @param token String containing an OpenAI API key. Defaults to the OPENAI_API_KEY environmental variable if not specified.
#' @return An httr2 request object
request_base <- function(task, token = Sys.getenv("OPENAI_API_KEY")) {
  if (!task %in% get_available_endpoints()) {
    cli::cli_abort(message = c(
      "{.var task} must be a supported endpoint",
      "i" = "Run {.run gptstudio::get_available_endpoints()} to get a list of supported endpoints"
    ))
  }
  httr2::request(getOption("gptstudio.openai_url")) %>%
    httr2::req_url_path_append(task) %>%
    httr2::req_auth_bearer_token(token = token)
}

#' Generate text completions using OpenAI's API for Chat
#'
#' @param model The model to use for generating text
#' @param prompt The prompt for generating completions
#' @param openai_api_key The API key for accessing OpenAI's API. By default, the
#'   function will try to use the `OPENAI_API_KEY` environment variable.
#' @param task The task that specifies the API url to use, defaults to
#' "completions" and "chat/completions" is required for ChatGPT model.
#'
#' @return A list with the generated completions and other information returned
#'   by the API.
#' @examples
#' \dontrun{
#' openai_create_completion(
#'   model = "text-davinci-002",
#'   prompt = "Hello world!"
#' )
#' }
#' @export
openai_create_chat_completion <-
  function(prompt = "<|endoftext|>",
           model = getOption("gptstudio.model"),
           openai_api_key = Sys.getenv("OPENAI_API_KEY"),
           task = "chat/completions") {
    assert_that(
      is.string(model),
      is.string(openai_api_key)
    )

    if (is.string(prompt)) {
      prompt <- list(
        list(
          role    = "user",
          content = prompt
        )
      )
    }

    body <- list(
      model = model,
      messages = prompt
    )

    query_openai_api(task = task, request_body = body, openai_api_key = openai_api_key)
  }


#' A function that sends a request to the OpenAI API and returns the response.
#'
#' @param task A character string that specifies the task to send to the API.
#' @param request_body A list that contains the parameters for the task.
#' @param openai_api_key String containing an OpenAI API key. Defaults to the OPENAI_API_KEY environmental variable if not specified.
#'
#' @return The response from the API.
#'
query_openai_api <- function(task, request_body, openai_api_key = Sys.getenv("OPENAI_API_KEY")) {
  response <- request_base(task, token = openai_api_key) %>%
    httr2::req_body_json(data = request_body) %>%
    httr2::req_retry(max_tries = 3) %>%
    httr2::req_error(is_error = function(resp) FALSE) %>%
    httr2::req_perform()

  # error handling
  if (httr2::resp_is_error(response)) {
    status <- httr2::resp_status(response)
    description <- httr2::resp_status_desc(response)

    cli::cli_abort(message = c(
      "x" = "OpenAI API request failed. Error {status} - {description}",
      "i" = "Visit the {.href [OpenAi Error code guidance](https://help.openai.com/en/articles/6891839-api-error-code-guidance)} for more details",
      "i" = "You can also visit the {.href [API documentation](https://platform.openai.com/docs/guides/error-codes/api-errors)}"
    ))
  }

  response %>%
    httr2::resp_body_json()
}



value_between <- function(x, lower, upper) {
  x >= lower && x <= upper
}


#' List supported models
#'
#' Get a list of the models supported by the OpenAI API.
#'
#' @param service The API service
#'
#' @return A character vector
#' @export
#'
#' @examples
#' get_available_endpoints()
get_available_models <- function(service) {
  if (service == "openai") {
    models <-
      request_base("models") %>%
      httr2::req_perform() %>%
      httr2::resp_body_json() %>%
      purrr::pluck("data") %>%
      purrr::map_chr("id")

    models <- models %>%
      stringr::str_subset("^gpt") %>%
      stringr::str_subset("instruct", negate = TRUE) %>%
      stringr::str_subset("vision", negate = TRUE) %>%
      sort()

    idx <- which(models == "gpt-3.5-turbo")
    models <- c(models[idx], models[-idx])
    return(models)
  } else if (service == "huggingface") {
    c("gpt2", "tiiuae/falcon-7b-instruct", "bigcode/starcoderplus")
  } else if (service == "anthropic") {
    c("claude-2", "claude-instant-1")
  } else if (service == "azure_openai") {
    "Using ENV variables"
  } else if (service == "perplexity") {
    c("pplx-7b-chat", "pplx-70b-chat", "pplx-7b-online", "pplx-70b-online",
      "llama-2-70b-chat", "codellama-34b-instruct", "mistral-7b-instruct",
      "mixtral-8x7b-instruct")
  } else if (service == "ollama") {
    if (!ollama_is_available()) stop("Couldn't find ollama in your system")
    ollama_list() %>%
      purrr::pluck("models") %>%
      purrr::map_chr("name")
  } else if (service == "cohere") {
    c("command", "command-light", "command-nightly", "command-light-nightly")
  } else if (service == "google") {
    get_available_models_google()
  }
}



#' List supported endpoints
#'
#' Get a list of the endpoints supported by gptstudio.
#'
#' @return A character vector
#' @export
#'
#' @examples
#' get_available_endpoints()
get_available_endpoints <- function() {
  c("completions", "chat/completions", "edits", "embeddings", "models")
}
