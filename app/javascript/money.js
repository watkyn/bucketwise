export const Money = {
  dollars(cents, keepNegative) {
    cents = keepNegative ? cents : Math.abs(cents);
    return (cents / 100).toFixed(2);
  },

  parse(fieldOrValue, keepNegative) {
    const value = typeof fieldOrValue === "string"
      ? document.getElementById(fieldOrValue)?.value || ""
      : fieldOrValue;
    return Money.parseValue(value, keepNegative);
  },

  parseValue(string, keepNegative) {
    const value = string.replace(/[^-+\d.]/g, "");
    const match = value.match(/^([-+]?)(\d*)(?:\.(\d*))?$/);

    if (!match) return 0;

    const sign = (match[1] === "-" && keepNegative) ? -1 : 1;
    const dollars = match[2].length > 0 ? parseInt(match[2]) : 0;

    let cents = 0;
    if (match[3] && match[3].length > 0) {
      const centsMagnitude = Math.pow(10, match[3].length);
      let centsText = match[3].replace(/^0+/, "");
      if (centsText === "") centsText = "0";
      cents = Math.round(parseInt(centsText) * 100 / centsMagnitude);
    }

    return sign * (dollars * 100 + cents);
  },

  format(fieldOrValue) {
    const value = typeof fieldOrValue === "string"
      ? document.getElementById(fieldOrValue)?.value || ""
      : fieldOrValue;
    return Money.formatValue(Money.parse(value, true));
  },

  formatValue(cents) {
    const sign = cents < 0 ? -1 : 1;
    let source = String(Math.abs(cents));
    let result;

    if (source.length > 2) {
      result = "." + source.slice(-2);
      source = source.slice(0, -2);
    } else if (source.length === 2) {
      result = "." + source;
      source = "";
    } else if (source.length === 1) {
      result = ".0" + source;
      source = "";
    } else {
      result = ".00";
    }

    while (source.length > 3) {
      result = "," + source.slice(-3) + result;
      source = source.slice(0, -3);
    }

    if (source.length > 0) {
      result = source + result;
    } else if (result[0] === ".") {
      result = "0" + result;
    }

    if (sign < 0) {
      result = "-" + result;
    }

    return result;
  }
};
