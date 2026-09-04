# Base set of human accounts, shared by every host.
#
# Hosts can add more by setting `bedrock.accounts.<user>` in their own
# module; the option is an attrset so definitions merge.
{ pkgs, ... }:
{
  bedrock.accounts = {
    expede = {
      name  = "Brooklyn Zelenka";
      email = "brooklyn@inkandswitch.com";
      shell = pkgs.fish;
      keys  = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUKVPRsoJEVWhHtz/2RhbVTZNvyNEm08KJK/3bOSdNc"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmJy3W56uqJjXGCHYOSJkLw+Ae/SgtF8B0qtjcDxtXp"
      ];
    };

    alexjg = {
      name  = "Alex Good";
      email = "alex@inkandswitch.com";
      shell = pkgs.zsh;
      keys  = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDfnGYUnlU6SKm6VGZQRxUGA+p9PgjEmaUhSKQeKx+pgAq8F1yRrmJQ6hsCsHrGu0+Rk/r1wi6MImUej2vmit8jO5wjBcv17EJM9bCXQUvrElLtaH+815r/DOIfyEsSpuZxe5tQ+IoKnasBQUKCkvGwBrPotJmqsHS5xqhke4/uGSid/g2ZSsF2ScLlD2E20+8OsTKw6nE+pfs+uchXwoiMmhclcyWK9cEwA9GLpPcjikQwdQThmeIZZGvRX7WvuPLZMp/AeoxCB+Y3KjEYpBtVS+rsv48GUAq2V0+SG35C1HJ3gGnKA+13xSdIHtfzxjlQy+7QWtagzF/0LlEgxm6gqsyC0xyDLDqiDxVRR8Nj0+ZXNejRNFubwg3YD4jx/JTIJ4u3/XDMlAw7wJGg1t3cMy+uR3/+cacsn5Py2nRZYvIxtBpToMKU9JOwVi6vz4kt+OeanLWP05a08XAnBW+c10P8qeN09he5Vvn6KL7cMr9RsGXzp9BHYqfc82PhskE="
        # alex-zephyrus
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpk50Fj8AnhhWB8y4tHHzUlDffwhxxeE6Ra81qbtXqJ1QSzam/eKn25usvRAWYijD7JzhJHBRSftCeF90dXBWMHjAWPaRYxn/J0vXYajuv3+7KV5g97Q5mTqVb6bRIW1gWprVF0+1I2aZaU1MG2sMf/jPd1+hN0JXC+vCvS8xYdxJFCQhWNzIhNX6q5G7gfLjYJ4598kQmCcmQ03OMVGfWx94DKr24fBF3eCLdw4Ub53iP/9ClzcxsmXNIJPbCaDAebmPS8uQSUkfhFVtcwBbllueW73y2kkMdFGhbFNmJXy2k4TReDZhIk6U113ehoiikjxOxDCNutdQODyPh04C48LG6+j4YGUPbkBPsjLyveWYWJw4tcGvREB0ZN+Cql6w7NXt8ZzfbEqK01pKBq7Bmhiq2DGNqE6A2PFmEyuvaOCyigP5jBgpB0K1N0h+T56IVFlDCGqLHcB5LaCiXMxKAAD26K6v+qc/G4/AxGozpd+BS3T6Bqm+pH1vWCdNEsz0="
      ];
    };

    alexwarth = {
      name  = "Alex Warth";
      email = "alexwarth@inkandswitch.com";
      shell = pkgs.zsh;
      keys  = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA1o2gb/keuxDxuk4QlZKcxWMSbvWDYLENX+6vEGA/4T9Yg6eL2g7ovRKo25/rOZV6hgc5TMt//VMSgJcf6LXJngmr3KkXe+QNu3a1jimosVhFwjule2U5R5dKETGupQ2kopBaV3PWLFb+ZbvhgdlY8HeFaOvUAybxfvLOmFtj1ta5VT2ccXPXKndCjfw/eaICknNhevi36KObCdj7Eh/BhI5kN77t61cPbQW+J29UubC6eqToVIFIMG0oD913rUV+yASpAPDsYz4FsMU8ONx8vjwUTQhWLYli3aKniVyHC4HNOoJ/cDlYHJ0+RoHzpKiQueEiHtdd1e2/YVW+K8F4mw=="
      ];
    };

    chee = {
      name  = "Chee Rabbits";
      email = "chee@inkandswitch.com";
      shell = pkgs.zsh;
      keys  = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHzdaK1G+GPAqG0GfinR6xMMTzmLX2DgFMDSnLE/vEmW yay@chee.party"
      ];
    };

    john = {
      name  = "John Mumm";
      email = "jtfmumm@inkandswitch.com";
      shell = pkgs.bash;
      keys  = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWVjwE2zAGZtqe95duKLtYsUsx9RaPVbn/i4QyQ/Y/b jtfmumm@gmail.com"
      ];
    };

    pvh = {
      name  = "Peter van Hardenberg";
      email = "pvh@inkandswitch.com";
      shell = pkgs.zsh;
      keys  = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxWJimKcZjUM4cyuroZ2brFclTxpDsoxQ3NjK43eWbn"
      ];
    };
  };
}
