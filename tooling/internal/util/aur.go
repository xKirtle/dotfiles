package util

func DetectPackageManager() string {
	helpers := []string{"paru", "yay", "pikaur", "trizen", "aurman", "pacaur", "pakku"}

	for _, h := range helpers {
		if HasBinary(h) {
			return h
		}
	}
	Fatalf(ExitFailure, "No AUR helper found. Supported helpers are: %v", helpers)
	return "" // unreachable
}
