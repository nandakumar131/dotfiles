return {
  "nvim-java/nvim-java",
  config = false,
  dependencies = {
    {
      "neovim/nvim-lspconfig",
      opts = {
        servers = {
          -- Your JDTLS configuration goes here
          jdtls = {
               settings = {
                 java = {
                   configuration = {
                     runtimes = {
                       {
                         name = "Java-21",
                         path = "/Users/nvadivelu/.sdkman/candidates/java/current",
                       },
                     },
                   },
                 },
               },
          },
        },
        setup = {
          jdtls = function()
            -- Your nvim-java configuration goes here
            require("java").setup({
              root_markers = {
              --   "settings.gradle",
              --   "settings.gradle.kts",
              --   "pom.xml",
              --   "build.gradle",
              --   "mvnw",
              --   "gradlew",
              --   "build.gradle",
              --   "build.gradle.kts",
                   ".git",
              },
            })
          end,
        },
      },
    },
  },
}
