#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

readonly well_known='.well-known/acme-challenge/'
declare single_cert='true'

echo " + Cloning letsencrypt.sh git repository..."
git submodule init
git submodule update

echo " + Generating alias configuration..."
for site_root in $(nfsn list-aliases); do
   if [[ -d "${DOCUMENT_ROOT}${site_root}/" ]]; then
      WELLKNOWN="${DOCUMENT_ROOT}${site_root}/${well_known}"
      CONFIGDIR="letsencrypt.sh/certs/${site_root}/"
      mkdir -p "${WELLKNOWN}" "${CONFIGDIR}"
      echo "WELLKNOWN='${WELLKNOWN}'" > "${CONFIGDIR}/config"
      unset single_cert
   fi
done

if [[ "$single_cert" ]]; then
   echo " + Generating fallback configuration..."
   mkdir -p "${DOCUMENT_ROOT}${well_known}"
   echo "WELLKNOWN='${DOCUMENT_ROOT}${well_known}'" > letsencrypt.sh/config
fi

echo " + Installing hook script..."
chmod +x nfsn-hook.sh
echo "HOOK='$(realpath nfsn-hook.sh)'" >> letsencrypt.sh/config

echo " + Generating domains.txt..."
nfsn ${single_cert:+-s} list-aliases > letsencrypt.sh/domains.txt

echo " + Performing initial run..."
letsencrypt.sh/letsencrypt.sh --cron

user_site=${MAIL##*/}
printf '
 + Done.

   Now add nfsn-cron.sh to your scheduled tasks so that the certificates
   will be renewed automatically.  To do that, go to

	https://members.nearlyfreespeech.net/%s/sites/%s/cron

   and use the following settings:

	Tag:                  lets-nfsn
	URL or Shell Command: %q %q
	User:                 me
	Hour:                 %d
	Day of Week:          Every
	Date:                 *

   The certificates will be renewed only when needed so it’s safe to
   schedule the task to run daily.

 + ATTN: /usr/local/bin/nfsn currently does not support being run from
         cron. A solution is being discussed; until one is available,
         this task will simply check the expiration date and error if it
         is within 30 days of expiry.
' \
	"${user_site%_*}" "$NFSN_SITE_NAME" \
	"$BASH" "$(realpath nfsn-cron.sh)" \
	"$(( $RANDOM % 24 ))"
