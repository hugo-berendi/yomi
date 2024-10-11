{...}: {
  accounts.calendar = {
    basePath = ".calendar";
    accounts = {
      "radicale" = {
        primary = true;
        remote = {
          type = "caldav";
          url = "";
          userName = "";
          passwordCommand = "";
        };
      };
    };
  };
}
