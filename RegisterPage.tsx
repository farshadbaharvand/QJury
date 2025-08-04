"use client";

import React, { useState, useEffect } from "react";
import { useAddress, useReadContract } from "thirdweb/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { JurorCard, JurorCardSkeleton } from "@/components/JurorCard";
import { 
  useRegisterJuror, 
  useGetAllJurors, 
  useGetJurorCount,
  Juror,
  transformJurorData 
} from "@/lib/contractUtils";
import { formatETH, formatWei } from "@/lib/formatters";
import { Users, Award, Clock, AlertCircle, CheckCircle } from "lucide-react";

export default function RegisterPage() {
  const [stakeAmount, setStakeAmount] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const address = useAddress();
  const { toast } = useToast();

  // Contract hooks
  const { mutateAsync: registerJuror, isPending: isRegistering } = useRegisterJuror();
  const { data: allJurorsData, isLoading: isLoadingJurors } = useGetAllJurors();
  const { data: jurorCount } = useGetJurorCount();

  // Check if user is already registered
  const { data: currentJurorData } = useReadContract({
    contract: "QJuryRegistry",
    method: "getJuror",
    params: [address]
  });

  const isAlreadyRegistered = currentJurorData && currentJurorData[0] !== "0x0000000000000000000000000000000000000000";

  const handleRegister = async () => {
    if (!address) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet to register as a juror.",
        variant: "destructive",
      });
      return;
    }

    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      toast({
        title: "Invalid stake amount",
        description: "Please enter a valid stake amount greater than 0.",
        variant: "destructive",
      });
      return;
    }

    try {
      setIsLoading(true);
      const stakeInWei = formatWei(stakeAmount);
      
      await registerJuror({
        args: [stakeInWei],
        overrides: {
          value: stakeInWei,
        },
      });

      toast({
        title: "Registration successful!",
        description: `You have been registered as a juror with ${stakeAmount} ETH stake.`,
      });

      setStakeAmount("");
    } catch (error: any) {
      console.error("Registration error:", error);
      toast({
        title: "Registration failed",
        description: error.message || "Failed to register as juror. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Transform jurors data
  const jurors: Juror[] = React.useMemo(() => {
    if (!allJurorsData) return [];
    
    try {
      // Assuming allJurorsData is an array of juror data
      return allJurorsData.map((jurorData: any) => transformJurorData(jurorData));
    } catch (error) {
      console.error("Error transforming jurors data:", error);
      return [];
    }
  }, [allJurorsData]);

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-6xl mx-auto">
        {/* Page Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-foreground mb-4 font-space-grotesk">
            Register as Juror
          </h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Join the QJury system and participate in decentralized dispute resolution. 
            Stake ETH to become eligible for jury selection.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Registration Form */}
          <div className="lg:col-span-1">
            <Card className="sticky top-8">
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Users className="h-5 w-5" />
                  <span>Juror Registration</span>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {!address ? (
                  <div className="text-center py-8">
                    <AlertCircle className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                    <p className="text-muted-foreground">
                      Please connect your wallet to register as a juror.
                    </p>
                  </div>
                ) : isAlreadyRegistered ? (
                  <div className="text-center py-8">
                    <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
                    <p className="text-foreground font-medium mb-2">Already Registered</p>
                    <p className="text-sm text-muted-foreground">
                      You are already registered as a juror.
                    </p>
                  </div>
                ) : (
                  <>
                    <div className="space-y-2">
                      <label htmlFor="stake" className="text-sm font-medium">
                        Stake Amount (ETH)
                      </label>
                      <Input
                        id="stake"
                        type="number"
                        placeholder="0.1"
                        value={stakeAmount}
                        onChange={(e) => setStakeAmount(e.target.value)}
                        min="0.01"
                        step="0.01"
                        disabled={isLoading || isRegistering}
                      />
                      <p className="text-xs text-muted-foreground">
                        Minimum stake: 0.01 ETH
                      </p>
                    </div>

                    <div className="space-y-4">
                      <div className="p-4 bg-muted/50 rounded-lg">
                        <h4 className="font-medium mb-2">Registration Benefits</h4>
                        <ul className="text-sm text-muted-foreground space-y-1">
                          <li>• Eligible for jury selection</li>
                          <li>• Earn rewards for correct decisions</li>
                          <li>• Participate in decentralized justice</li>
                          <li>• Build reputation in the system</li>
                        </ul>
                      </div>

                      <Button
                        onClick={handleRegister}
                        disabled={!stakeAmount || isLoading || isRegistering}
                        className="w-full"
                        size="lg"
                      >
                        {isLoading || isRegistering ? (
                          <>
                            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
                            Registering...
                          </>
                        ) : (
                          <>
                            <Users className="mr-2 h-4 w-4" />
                            Register as Juror
                          </>
                        )}
                      </Button>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Current Jurors */}
          <div className="lg:col-span-2">
            <div className="mb-6">
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-foreground">
                  Registered Jurors
                </h2>
                <Badge variant="outline" className="text-sm">
                  {jurorCount ? Number(jurorCount) : 0} Total
                </Badge>
              </div>
              <p className="text-muted-foreground mt-2">
                Active jurors in the QJury system
              </p>
            </div>

            {isLoadingJurors ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {Array.from({ length: 6 }).map((_, index) => (
                  <JurorCardSkeleton key={index} />
                ))}
              </div>
            ) : jurors.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {jurors.map((juror, index) => (
                  <JurorCard
                    key={juror.address || index}
                    juror={juror}
                    showActions={false}
                  />
                ))}
              </div>
            ) : (
              <Card>
                <CardContent className="text-center py-12">
                  <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                  <p className="text-muted-foreground">
                    No jurors registered yet. Be the first to join!
                  </p>
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}