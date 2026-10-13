# Machine identity.
#
# Everything that answers "who am I" lives here, so moving this configuration
# to another machine or account means editing one file instead of grepping for
# "alex". Darwin modules get it as the `identity` module argument; Home Manager
# gets it through `extraSpecialArgs`.
{
  username = "alex";
  home = "/Users/alex";
  fullName = "Alex Pawlowski";
  email = "pawlowski.alx@gmail.com";
}
