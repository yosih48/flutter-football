import 'package:url_launcher/url_launcher.dart';

class TeamLinkHandler {
  static void linkToTeam(String teamName) async {
    String url;
    switch (teamName) {
      case "RB Leipzig":
        url = "https://www.365scores.com/he/football/team/rb-leipzig-7171";
        break;
      case "Newcastle":
        url = "https://www.365scores.com/he/football/team/newcastle-116";
        break;
      case "AC Milan":
        url = "https://www.365scores.com/he/football/team/ac-milan-227";
        break;
    
      case "FC Porto":
        url ="https://www.365scores.com/he/football/team/fc-porto-887";
        break;
      case "Manchester City":
        url =
            "https://www.365scores.com/he/football/team/manchester-city-110";
        break;
      case "Real Madrid":
        url =
            "https://www.365scores.com/he/football/team/real-madrid-131";
        break;
      case "BSC Young Boys":
        url =
            "https://www.365scores.com/he/football/team/young-boys-1139";
        break;
      case "Celtic":
        url =
            "https://www.365scores.com/he/football/team/celtic-754";
        break;
      case "Feyenoord":
        url ="https://www.365scores.com/he/football/team/feyenoord-691";
        break;
      case "Atletico Madrid":
        url =
            "https://www.365scores.com/he/football/team/atletico-madrid-134";
        break;
      case "Lazio":
        url =
            "https://www.365scores.com/he/football/team/lazio-236";
        break;
      case "Borussia Dortmund":
        url ="https://www.365scores.com/he/football/team/dortmund-341";
        break;
      case "Paris Saint Germain":
        url =
            "https://www.365scores.com/he/football/team/psg-480";
        break;
      case "FK Crvena Zvezda":
        url =
            "https://www.365scores.com/he/football/team/fk-crvena-zvezda-8957";
        break;
      case "Antwerp":
        url =
            "https://www.365scores.com/he/football/team/royal-antwerp-fc-1191";
        break;
      case "Barcelona":
        url =
            "https://www.365scores.com/he/football/team/fc-barcelona-132";
        break;
      case "Shakhtar Donetsk":
        url =
            "https://www.365scores.com/he/football/team/shakhtar-donetsk-1955";
        break;
      case "FC Copenhagen":
        url =
            "https://www.365scores.com/he/football/team/fc-copenhagen-1824";
        break;
      case "Galatasaray":
        url =
            "https://www.365scores.com/he/football/team/galatasaray-945";
        break;
      case "Union Berlin":
        url =
            "https://www.365scores.com/he/football/team/union-berlin-392";
        break;
      case "Manchester United":
        url =
            "https://www.365scores.com/he/football/team/manchester-united-105";
        break;
      case "Bayern Munich":
        url =
            "https://www.365scores.com/he/football/team/bayern-munich-331";
        break;
      case "Lens":
        url =
            "https://www.365scores.com/he/football/team/lens-481";
        break;
      case "Sevilla":
        url =
            "https://www.365scores.com/he/football/team/sevilla-135";
        break;
      case "PSV Eindhoven":
        url =
            "https://www.365scores.com/he/football/team/psv-eindhoven-725";
        break;
      case "Arsenal":
        url =
            "https://www.365scores.com/he/football/team/arsenal-104";
        break;
      case "Napoli":
        url =
            "https://www.365scores.com/he/football/team/napoli-234";
        break;
      case "SC Braga":
        url ="https://www.365scores.com/he/football/team/sc-braga-895";
        break;
      case "Red Bull Salzburg":
        url =
            "https://www.365scores.com/he/football/team/red-bull-salzburg-1739";

        break;
      case "Benfica":
        url =
            "https://www.365scores.com/he/football/team/benfica-888";
        break;
      case "Inter":
        url =
            "https://www.365scores.com/he/football/team/inter-milan-224";
        break;
      case "Real Sociedad":
        url =
            "https://www.365scores.com/he/football/team/real-sociedad-154";
        break;
      case "Maccabi Haifa":
        url =
            "https://www.365scores.com/he/football/team/maccabi-haifa-562";
        break;
      case "Maccabi Tel Aviv":
        url =
            "https://www.365scores.com/he/football/team/maccabi-tel-aviv-566";
        break;
      case "Ashdod":
        url ="https://www.365scores.com/he/football/team/sc-ashdod-569";
        break;
      case "Beitar Jerusalem":
        url =
            "https://www.365scores.com/he/football/team/beitar-jerusalem-559";
        break;
      case "Hapoel Haifa":
        url =
            "https://www.365scores.com/he/football/team/hapoel-haifa-575";
        break;
      case "Maccabi Petah Tikva":
        url =
            "https://www.365scores.com/he/football/team/maccabi-petah-tikva-564";
        break;
      case "Hapoel Katamon":
        url =
            "https://www.365scores.com/he/football/team/hapoel-jerusalem-614";
        break;
      case "Hapoel Hadera":
        url =
            "https://www.365scores.com/he/football/team/hapoel-hadera-627";
        break;
      case "Maccabi Netanya":
        url =
            "https://www.365scores.com/he/football/team/maccabi-netanya-560";
        break;
      case "Hapoel Tel Aviv":
        url =
            "https://www.365scores.com/he/football/team/hapoel-tel-aviv-567";
        break;
      case "Bnei Sakhnin":
        url =
            "https://www.365scores.com/he/football/team/bnei-sakhnin-561";
        break;
      case "Hapoel Petah Tikva":
        url =
            "https://www.365scores.com/he/football/team/hapoel-petah-tikva-571";
        break;
      case "Maccabi Bnei Raina":
        url =
            "https://www.365scores.com/he/football/team/maccabi-bnei-reineh-45617";
        break;
      case "Hapoel Beer Sheva":
        url =
            "https://www.365scores.com/he/football/team/hapoel-beer-sheva-579";
        break;
      case "Rennes":
        url =
            "https://www.365scores.com/he/football/team/rennes-477";
        break;
      case "SC Freiburg":
        url ="https://www.365scores.com/he/football/team/freiburg-354";
        break;
      case "Toulouse":
        url ="https://www.365scores.com/he/football/team/toulouse-482";
        break;
      case "Qarabag":
        url =
            "https://www.365scores.com/he/football/team/qarabag-agdam-7521";
        break;
      case "Ludogorets":
        url =
            "https://www.365scores.com/he/football/team/ludogorets-8528";
        break;
      case "Servette FC":
        url =
            "https://www.365scores.com/he/football/team/servette-fc-1154";
        break;
      case "Real Betis":
        url ="https://www.365scores.com/he/football/team/real-betis-146";
        break;
      case "Bodo/Glimt":
        url =
            "https://www.365scores.com/he/football/team/bodo-glimt-1978";
        break;
      case "Ajax":
        url =
            "https://www.365scores.com/he/football/team/ajax-690";
        break;
      case "AS Roma":
        url =
            "https://www.365scores.com/he/football/team/as-roma-225";
        break;
      case "Sporting CP":
        url =
            "https://www.365scores.com/he/football/team/sporting-cp-890";
        break;
      case "Sparta Praha":
        url =
            "https://www.365scores.com/he/football/team/sparta-praha-1788";
        break;
      case "Marseille":
        url =
            "https://www.365scores.com/he/football/team/olympique-de-marseille-469";
        break;
      case "Slovan Bratislava":
        url =
            "https://www.365scores.com/he/football/team/slovan-bratislava-2112";
        break;
      case "Sturm Graz":
        url =
            "https://www.365scores.com/he/football/team/sturm-graz-1741";
        break;
      case "Eintracht Frankfurt":
        url =
            "https://www.365scores.com/he/football/team/eintracht-frankfurt-337";
        break;
      case "Union St. Gilloise":
        url =
            "https://www.365scores.com/he/football/team/union-st.-gilloise-1204";
        break;
      case "Ferencvarosi TC":
        url =
            "https://www.365scores.com/he/football/team/ferencvaros-6020";
        break;
      case "Olympiakos Piraeus":
        url =
            "https://www.365scores.com/he/football/team/olympiacos-1023";
        break;
      case "Legia Warszawa":
        url =
            "https://www.365scores.com/he/football/team/legia-warszawa-2209";
        break;
      case "Molde":
        url =
            "https://www.365scores.com/he/football/team/molde-1983";
        break;
      case "Dinamo Zagreb":
        url =
            "https://www.365scores.com/he/football/team/dinamo-zagreb-2245";
        break;
      case "Germany":
        url ="https://www.365scores.com/he/football/team/germany-2372";
        break;
      case "Scotland":
        url ="https://www.365scores.com/he/football/team/scotland-5069";
        break;
      case "Hungary":
        url ="https://www.365scores.com/he/football/team/hungary-5026";
        break;
      case "Switzerland":
        url =
            "https://www.365scores.com/he/football/team/switzerland-5032";
        break;
      case "Spain":
        url =
            "https://www.365scores.com/he/football/team/spain-5050";
        break;
      case "Croatia":
        url ="https://www.365scores.com/he/football/team/croatia-5055";
        break;
      case "Italy":
        url =
            "https://www.365scores.com/he/football/team/italy-2375";
        break;
      case "Albania":
        url ="https://www.365scores.com/he/football/team/albania-5029";
        break;
      case "Poland":
        url =
            "https://www.365scores.com/he/football/team/poland-5038";
        break;
      case "Netherlands":
        url =
            "https://www.365scores.com/he/football/team/netherlands-2377";
        break;
      case "Slovenia":
        url ="https://www.365scores.com/he/football/team/slovenia-5041";
        break;
      case "Denmark":
        url ="https://www.365scores.com/he/football/team/denmark-5027";
        break;
      case "Serbia":
        url =
            "https://www.365scores.com/he/football/team/serbia-2374";
        break;
      case "England":
        url ="https://www.365scores.com/he/football/team/england-5054";
        break;
      case "Romania":
        url ="https://www.365scores.com/he/football/team/romania-5060";
        break;
      case "Ukraine":
        url ="https://www.365scores.com/he/football/team/ukraine-5057";
        break;
      case "Belgium":
        url ="https://www.365scores.com/he/football/team/belgium-2373";
        break;
      case "Slovakia":
        url ="https://www.365scores.com/he/football/team/slovakia-5039";
        break;
      case "Austria":
        url ="https://www.365scores.com/he/football/team/austria-5059";
        break;
      case "France":
        url =
            "https://www.365scores.com/he/football/team/france-5061";
        break;
      case "Turkey":
        url ="https://www.365scores.com/he/football/team/turkiye-5047";
        break;
      case "Portugal":
        url ="https://www.365scores.com/he/football/team/portugal-5028";
        break;
      case "Czech Republic":
        url =
            "https://www.365scores.com/he/football/team/czech-republic-5040";
        break;
      default:
        print("No predefined URL found for team: $teamName");
        // Fallback to a search URL if no predefined URL is found
        url =
            "https://www.365scores.com/he/search?q=${Uri.encodeComponent(teamName)}";
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch $url");
      // Fallback to opening the main website if the specific URL fails
      const fallbackUrl = "https://www.365scores.com";
      if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $fallbackUrl';
      }
    }
  }
}
